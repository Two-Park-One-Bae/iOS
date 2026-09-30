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
        /// 첫 조회(보여 줄 목록이 없을 때)만 true — 조건을 바꿔 다시 조회하는 동안은 이전 화면을 둔다(spec NM-529).
        let isSearching: AnyPublisher<Bool, Never>
        /// 입력 전 — 속성 토큰도 조건도 없어 조회하지 않았다(spec NM-529).
        let awaitingInput: AnyPublisher<Void, Never>
        /// 이어서 조회(21번째부터) 실패 — 보이는 후보는 두고 목록 끝에 한 줄 + 다시 시도. 자동 재시도 없음.
        let loadMoreFailed: AnyPublisher<Bool, Never>
        /// 조회 실패 — 로딩을 멈추고 다시 시도를 보여 준다.
        let searchFailed: AnyPublisher<Void, Never>
        /// 헤더용 후보 수 — ids 수 − 사라진 품목, `truncated` 면 `200개+`.
        let summary: AnyPublisher<CandidateSummary, Never>
    }

    struct CandidateSummary: Equatable {
        let count: Int
        let truncated: Bool
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
    /// 수정 기록도 조건처럼 Coordinator 가 받아 보관한다 — 다시 열면 이어서 센다(NM-535).
    let editRecordSubject: CurrentValueSubject<PillEditRecord, Never>

    // MARK: - Streams

    /// 지금 목록에 보이는 후보 — 재조회 중에도 응답이 오기 전까지는 이 목록을 둔다.
    private var shown: [PillCandidateModel] = []
    private let candidatesSubject = PassthroughSubject<[PillCandidateModel], Never>()
    private let searchingSubject = PassthroughSubject<Bool, Never>()
    private let searchFailedSubject = PassthroughSubject<Void, Never>()
    private let awaitingInputSubject = PassthroughSubject<Void, Never>()
    private let loadMoreFailedSubject = PassthroughSubject<Bool, Never>()
    /// 이어서 조회가 실패하면 사용자가 다시 시도할 때까지 멈춘다 — 스크롤로 저절로 재요청하지 않는다.
    private var loadMoreFailed = false
    private let summarySubject = PassthroughSubject<CandidateSummary, Never>()
    // 조건 변경 → 재조회 트리거. 연타/빠른 변경 시 디바운스로 마지막 값만 검색.
    private let editTrigger = PassthroughSubject<Void, Never>()
    private var didLoad = false
    // 서버가 정렬을 끝낸 순서(≤200). 21번째부터는 이 목록을 잘라 ID 로 조회한다 — 커서가 없다(NM-489).
    private var ids: [String] = []
    private var truncated = false
    private var missingCount = 0
    /// ids 중 다음에 조회할 위치.
    private var nextIndex = 0
    private var searchCancellable: AnyCancellable?
    private var loadMoreCancellable: AnyCancellable?
    private var cancelBag = Set<AnyCancellable>()

    /// 한 번에 이어 받는 후보 수 — 서버 한도(1~50).
    private static let itemsPageSize = 50

    // MARK: - Init

    init(
        pillIndex: Int,
        displayNumber: Int,
        conditions: PillConditions,
        editRecord: PillEditRecord = PillEditRecord(),
        thumbnail: UIImage?,
        isManual: Bool = false,
        startsExpanded: Bool = false
    ) {
        self.pillIndex = pillIndex
        self.displayNumber = displayNumber
        self.conditionsSubject = CurrentValueSubject(conditions)
        self.editRecordSubject = CurrentValueSubject(editRecord)
        self.thumbnail = thumbnail
        self.isManual = isManual
        self.startsExpanded = startsExpanded || isManual
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
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
            isSearching: searchingSubject.eraseToAnyPublisher(),
            awaitingInput: awaitingInputSubject.eraseToAnyPublisher(),
            loadMoreFailed: loadMoreFailedSubject.removeDuplicates().eraseToAnyPublisher(),
            searchFailed: searchFailedSubject.eraseToAnyPublisher(),
            summary: summarySubject.eraseToAnyPublisher()
        )
    }

    // MARK: - Analytics (조건 편집 추적)

    /// 이 알약을 처음 연 뒤로 수정한 횟수 — 화면을 닫았다 열어도 이어진다.
    var editCount: Int { editRecordSubject.value.count }
    /// 확정까지 수정한 속성 종류 (pill_confirm.edited_attrs).
    var editedAttrsJoined: String { editRecordSubject.value.joinedAttributes }
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
        var record = editRecordSubject.value
        record.record(attribute)
        editRecordSubject.send(record)
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

    /// 신규 검색(최초 · 조건 변경 · 다시 시도) — 진행 중인 조회를 끊고 처음부터 다시 받는다.
    /// 조건은 PillConditions.query 가 사용자값만 추린다(토큰 · 임베딩 · 각인 출처 포함).
    private func fetchCandidates() {
        searchCancellable = nil
        loadMoreCancellable = nil
        // 이전 조건의 순서로 이어 받지 않도록 비운다 — 새 응답이 오기 전 loadMore 는 아무것도 하지 않는다.
        ids = []
        nextIndex = 0
        setLoadMoreFailed(false)
        let query = conditions.query
        guard !query.isWithoutInput else {
            shown = []
            awaitingInputSubject.send(())
            return
        }
        // 스피너는 보여 줄 목록이 없을 때만 — 조건을 바꿔 다시 조회할 때 목록이 깜빡이지 않게(spec NM-529).
        if shown.isEmpty { searchingSubject.send(true) }
        searchCancellable = pillUseCase.fetchPillCandidates(query: query)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self, case .failure = completion else { return }
                // 실패해도 로딩에 머물지 않는다 — 다시 시도를 보여 준다. 이전 목록은 지운다(조건이 바뀌어 맞지 않는다).
                self.shown = []
                self.searchingSubject.send(false)
                self.searchFailedSubject.send(())
            } receiveValue: { [weak self] result in
                guard let self else { return }
                self.ids = result.ids
                self.truncated = result.truncated
                self.missingCount = 0
                self.nextIndex = min(result.candidates.count, result.ids.count)
                self.searchingSubject.send(false)
                // 개수를 먼저 — 화면은 목록을 다시 그릴 때 헤더도 함께 그린다.
                self.sendSummary()
                self.shown = result.candidates
                self.candidatesSubject.send(result.candidates)
            }
    }

    func retry() {
        fetchCandidates()
    }

    /// 다음 구간 — 목록 끝에 다다르면 호출(VC willDisplay). ids 순서대로 이어 붙이고, 사라진 품목은 뺀다.
    /// 실패하면 멈추고 목록 끝에 다시 시도를 보인다 — 사용자가 누를 때까지 재요청하지 않는다(spec NM-529).
    func loadMore() {
        guard loadMoreCancellable == nil, !loadMoreFailed, nextIndex < ids.count else { return }
        let chunk = Array(ids[nextIndex..<min(nextIndex + Self.itemsPageSize, ids.count)])
        loadMoreCancellable = pillUseCase.fetchPillCandidateItems(pillCodes: chunk)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self, case .failure = completion else { return }
                self.loadMoreCancellable = nil
                self.setLoadMoreFailed(true)
            } receiveValue: { [weak self] result in
                guard let self else { return }
                let byCode = Dictionary(result.items.map { ($0.pillCode, $0) }, uniquingKeysWith: { first, _ in first })
                let ordered = chunk.compactMap { byCode[$0] }
                // missing 에 없는데 items 에도 없는 ID 도 빠진 것으로 센다 — 로딩으로 남기지 않는다.
                self.missingCount += chunk.count - ordered.count
                self.nextIndex += chunk.count
                self.loadMoreCancellable = nil
                self.sendSummary()
                self.shown += ordered
                self.candidatesSubject.send(self.shown)
            }
    }

    /// 목록 끝 '다시 시도' — 같은 구간을 다시 요청한다. 식별 횟수를 쓰지 않는다(후보 조회는 429 없음).
    func retryLoadMore() {
        setLoadMoreFailed(false)
        loadMore()
    }

    private func setLoadMoreFailed(_ failed: Bool) {
        loadMoreFailed = failed
        loadMoreFailedSubject.send(failed)
    }

    private func sendSummary() {
        summarySubject.send(CandidateSummary(count: ids.count - missingCount, truncated: truncated))
    }
}
