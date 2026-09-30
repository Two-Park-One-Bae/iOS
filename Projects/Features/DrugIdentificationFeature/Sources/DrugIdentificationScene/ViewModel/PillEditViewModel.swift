import Combine
import UIKit
import Core
import Domain

// ⑧ 알약 수정 — 조건을 바꾸면 실시간으로 후보를 재조회 (NM-513 · NM-490)
//
// 조건 규칙(3단 · 모델값/사용자값 · 되돌리기 · 칸 색)은 Domain `PillConditions` 가 갖는다.
// 이 ViewModel 은 화면 입력을 그 규칙에 넘기고, 바뀔 때마다 후보를 다시 찾는다.
final class PillEditViewModel {

    // MARK: - Input / Output

    struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
    }

    struct Output {
        let candidates: AnyPublisher<[PillCandidateModel], Never>
        let isEmpty: AnyPublisher<Bool, Never>
        let isSearching: AnyPublisher<Bool, Never>
    }

    // MARK: - Dependencies

    @Injected private var pillUseCase: PillUseCase

    // MARK: - Immutable

    /// 이 흐름 안의 고정 식별자(분석 · 결과 반영 키).
    let pillIndex: Int
    /// 결과 화면에 보이는 번호 — 삭제·추가로 다시 매겨질 수 있다. 제목은 이걸 쓴다.
    let displayNumber: Int
    let thumbnail: UIImage?
    /// 수동 추가(NM-187) 알약 여부. true면 편집·확정·이탈 이벤트를 집계에서 제외한다.
    /// (검출 모델과 무관 — pill_attr_edit/pill_confirm/pill_flow_exit 정확도 지표 오염 방지)
    let isManual: Bool
    /// 처음부터 펼친 상태로 연다 — 수동 추가 · 추출 실패는 보여 줄 모델 값이 없어 바로 입력하게 한다.
    let startsExpanded: Bool

    // MARK: - State

    /// 알약 한 개의 조건. 화면을 닫았다 열어도 이어지도록 Coordinator 가 받아 보관한다.
    let conditionsSubject: CurrentValueSubject<PillConditions, Never>
    var conditions: PillConditions { conditionsSubject.value }

    // MARK: - Streams

    private let candidatesSubject = CurrentValueSubject<[PillCandidateModel], Never>([])
    private let searchingSubject = PassthroughSubject<Bool, Never>()
    // 조건 변경 → 재조회 트리거. 연타/빠른 변경 시 디바운스로 마지막 값만 검색.
    private let editTrigger = PassthroughSubject<Void, Never>()
    private var didLoad = false
    // 커서 페이지네이션 — 아래로 스크롤 시 다음 페이지를 이어 붙인다. (v1 ids 방식으로 바뀌면 NM-514 에서 교체)
    private var nextCursor: String?
    private var hasNext = false
    private var isLoadingMore = false
    private var appendNextPage = false
    private var cancelBag = Set<AnyCancellable>()

    // MARK: - Init

    init(
        pillIndex: Int,
        displayNumber: Int,
        conditions: PillConditions,
        thumbnail: UIImage?,
        isManual: Bool = false,
        startsExpanded: Bool = false
    ) {
        self.pillIndex = pillIndex
        self.displayNumber = displayNumber
        self.conditionsSubject = CurrentValueSubject(conditions)
        self.thumbnail = thumbnail
        self.isManual = isManual
        self.startsExpanded = startsExpanded || isManual
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        pillUseCase.pillCandidates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] page in
                guard let self else { return }
                self.searchingSubject.send(false)
                self.nextCursor = page.nextCursor
                self.hasNext = page.hasNext
                if self.appendNextPage {
                    self.candidatesSubject.send(self.candidatesSubject.value + page.candidates)
                } else {
                    self.candidatesSubject.send(page.candidates)
                }
                self.appendNextPage = false
                self.isLoadingMore = false
            }
            .store(in: &cancelBag)

        input.viewDidLoad
            .sink { [weak self] in
                guard let self, !self.didLoad else { return }
                self.didLoad = true
                self.fetchCandidates()
            }
            .store(in: &cancelBag)

        // 조건 변경을 300ms 디바운스 → 손을 멈춘 뒤 한 번만 재조회.
        editTrigger
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.fetchCandidates() }
            .store(in: &cancelBag)

        return Output(
            candidates: candidatesSubject.eraseToAnyPublisher(),
            isEmpty: candidatesSubject.map { $0.isEmpty }.eraseToAnyPublisher(),
            isSearching: searchingSubject.eraseToAnyPublisher()
        )
    }

    // MARK: - Analytics (조건 편집 추적)

    private(set) var editCount = 0
    private var editedAttrs: Set<String> = []
    /// 확정까지 수정한 속성 종류 (pill_confirm.edited_attrs, ≤100자).
    /// 수정 없이 확정하는 게 다수 케이스인데 빈 문자열을 보내면 GA4 에서 (not set) 으로 보여
    /// "파라미터가 안 왔다"와 구분이 안 된다 — enteredValuesSummary 와 같이 "none" 으로 명시한다.
    var editedAttrsJoined: String {
        let joined = editedAttrs.isEmpty ? "none" : editedAttrs.sorted().joined(separator: ",")
        return String(joined.prefix(100))
    }
    /// 이탈 시 지금까지 사용자가 정한 조건 요약 (pill_flow_exit.entered_values, ≤100자).
    var enteredValuesSummary: String {
        let c = conditions
        var parts: [String] = []
        if c.shape.userValue != nil { parts.append("shape") }
        if c.colors.userValue != nil { parts.append("color") }
        if c.formulation.userValue != nil { parts.append("formulation") }
        let faces = [c.front, c.back]
        if faces.contains(where: { if case .value(_, .user) = $0.imprint { return true }; return $0.imprint == .none }) {
            parts.append("imprint")
        }
        if faces.contains(where: { $0.dividingLine != .all }) { parts.append("dividing_line") }
        if faces.contains(where: { if case .present(.user) = $0.mark { return true }; return $0.mark == .none }) {
            parts.append("mark")
        }
        return String((parts.isEmpty ? "none" : parts.joined(separator: ",")).prefix(100))
    }

    private func recordEdit(_ attribute: String) {
        editCount += 1
        editedAttrs.insert(attribute)
        guard !isManual else { return }   // 수동 추가 알약은 집계 제외(모델 정확도 지표 오염 방지)
        AppAnalytics.track(.pillAttrEdit(attribute: attribute, pillIndex: pillIndex))
    }

    // MARK: - Edits (바뀔 때마다 실시간 재조회)

    private func apply(_ attribute: String, _ change: (inout PillConditions) -> Void) {
        var next = conditions
        change(&next)
        guard next != conditions else { return }
        conditionsSubject.send(next)
        recordEdit(attribute)
        editTrigger.send(())
    }

    func setColors(_ colors: [PillColorModel]) { apply("color") { $0.setColors(colors) } }
    func setShape(_ shape: PillShapeModel?) { apply("shape") { $0.setShape(shape) } }
    func setFormulation(_ formulation: PillFormulationModel?) { apply("formulation") { $0.setFormulation(formulation) } }
    func submitImprint(_ text: String, on face: PillFace) { apply("imprint") { $0.submitImprint(text, on: face) } }
    func setImprint(_ condition: ImprintCondition, on face: PillFace) { apply("imprint") { $0.setImprint(condition, on: face) } }
    func revertImprint(on face: PillFace) { apply("imprint") { $0.revertImprint(on: face) } }
    func setDividingLine(_ condition: DividingLineCondition, on face: PillFace) {
        apply("dividing_line") { $0.setDividingLine(condition, on: face) }
    }
    func setMark(_ condition: MarkCondition, on face: PillFace) { apply("mark") { $0.setMark(condition, on: face) } }

    // MARK: - Fetch

    /// 임시 — 서버 v1 후보 조회(NM-514 D)가 붙기 전까지 조건을 v0 요청 모양으로 옮긴다.
    /// 사용자가 고른 값만 담는 건 v1 과 같다. 토큰 · 임베딩 · 각인 출처는 v0 에 자리가 없어 빠진다.
    private var legacyRequest: (colors: [PillColorModel]?, shape: PillShapeModel?, formulation: PillFormulationModel?,
                                front: PillFaceModel?, back: PillFaceModel?) {
        let q = conditions.query
        func face(_ f: PillFaceQuery?) -> PillFaceModel? {
            guard let f else { return nil }
            let line: DividingLineModel?
            switch f.dividingLine {
            case .plus?:  line = .plus
            case .minus?: line = .minus
            default:      line = nil   // v0 은 '구분선 없음' 조건을 표현하지 못한다
            }
            return PillFaceModel(imprint: f.imprint, dividingLine: line, hasMark: f.hasMark)
        }
        return (q.colors.isEmpty ? nil : q.colors, q.shape, q.formulation, face(q.front), face(q.back))
    }

    // 신규 검색(최초·조건 변경) — 첫 페이지부터 다시 조회하고 목록을 교체한다.
    private func fetchCandidates() {
        appendNextPage = false
        isLoadingMore = false
        nextCursor = nil
        hasNext = false
        searchingSubject.send(true)
        let r = legacyRequest
        pillUseCase.fetchPillCandidates(
            colors: r.colors, isTransparent: nil, shape: r.shape, formulation: r.formulation,
            front: r.front, back: r.back, cursor: nil, size: 20
        )
    }

    // 다음 페이지 — 아래로 스크롤해 목록 끝에 다다르면 호출(VC willDisplay). 결과를 기존 목록에 이어 붙인다.
    func loadMore() {
        guard hasNext, !isLoadingMore, let cursor = nextCursor else { return }
        isLoadingMore = true
        appendNextPage = true
        let r = legacyRequest
        pillUseCase.fetchPillCandidates(
            colors: r.colors, isTransparent: nil, shape: r.shape, formulation: r.formulation,
            front: r.front, back: r.back, cursor: cursor, size: 20
        )
    }
}
