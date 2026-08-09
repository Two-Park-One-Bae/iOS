import Combine
import UIKit
import Core
import Domain

// ⑧ 알약 수정 — 속성 편집 시 실시간으로 후보를 재조회
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

    let pillIndex: Int
    let thumbnail: UIImage?
    /// 수동 추가(NM-187) 알약 여부. true면 편집·확정·이탈 이벤트를 집계에서 제외한다.
    /// (검출 모델과 무관 — pill_attr_edit/pill_confirm/pill_flow_exit 정확도 지표 오염 방지)
    let isManual: Bool

    // MARK: - Editable Attribute State

    private(set) var colors: [PillColorModel]
    private(set) var isTransparent: Bool
    private(set) var shape: PillShapeModel?
    private(set) var formulation: PillFormulationModel?
    private(set) var front: PillFaceModel?
    private(set) var back: PillFaceModel?

    // MARK: - Streams

    private let candidatesSubject = CurrentValueSubject<[PillCandidateModel], Never>([])
    private let searchingSubject = PassthroughSubject<Bool, Never>()
    // 속성 편집 → 재조회 트리거. 연타/빠른 변경 시 디바운스로 마지막 값만 검색(상용 검색앱 방식).
    private let editTrigger = PassthroughSubject<Void, Never>()
    private var didLoad = false
    // 커서 페이지네이션 — 아래로 스크롤 시 다음 페이지를 이어 붙인다.
    private var nextCursor: String?
    private var hasNext = false
    private var isLoadingMore = false
    // 다음 응답을 기존 목록에 append(true)할지 교체(false)할지. loadMore=append, 신규 검색=교체.
    private var appendNextPage = false
    private var cancelBag = Set<AnyCancellable>()

    // MARK: - Init

    init(pillIndex: Int, attribute: PillAttributeModel, thumbnail: UIImage?, isManual: Bool = false) {
        self.pillIndex = pillIndex
        self.thumbnail = thumbnail
        self.isManual = isManual
        self.colors = attribute.colors
        self.isTransparent = attribute.isTransparent
        self.shape = attribute.shape
        self.formulation = attribute.formulation
        self.front = attribute.front
        self.back = attribute.back
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

        // 편집 트리거를 300ms 디바운스 → 손을 멈춘 뒤 한 번만 재조회.
        editTrigger
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.fetchCandidates() }
            .store(in: &cancelBag)

        let isEmpty = candidatesSubject
            .map { $0.isEmpty }
            .eraseToAnyPublisher()

        return Output(
            candidates: candidatesSubject.eraseToAnyPublisher(),
            isEmpty: isEmpty,
            isSearching: searchingSubject.eraseToAnyPublisher()
        )
    }

    // MARK: - Analytics (속성 편집 추적)

    private(set) var editCount = 0
    private var editedAttrs: Set<String> = []
    /// 확정까지 수정한 속성 종류 (pill_confirm.edited_attrs).
    var editedAttrsJoined: String { editedAttrs.sorted().joined(separator: ",") }
    /// 이탈 시 지금까지 입력된 속성 요약 (pill_flow_exit.entered_values, ≤100자).
    var enteredValuesSummary: String {
        var parts: [String] = []
        if shape != nil { parts.append("shape") }
        if !colors.isEmpty { parts.append("color") }
        if isTransparent { parts.append("transparent") }
        if formulation != nil { parts.append("formulation") }
        if front != nil || back != nil { parts.append("imprint") }
        return String((parts.isEmpty ? "none" : parts.joined(separator: ",")).prefix(100))
    }

    private func recordEdit(_ attribute: String) {
        editCount += 1
        editedAttrs.insert(attribute)
        guard !isManual else { return }   // 수동 추가 알약은 집계 제외(모델 정확도 지표 오염 방지)
        AppAnalytics.track(.pillAttrEdit(attribute: attribute, pillIndex: pillIndex))
    }

    // MARK: - Edits (변경 시 실시간 재조회)

    func updateColors(_ colors: [PillColorModel]) {
        self.colors = colors
        recordEdit("color")
        editTrigger.send(())
    }

    func setTransparent(_ isTransparent: Bool) {
        self.isTransparent = isTransparent
        recordEdit("transparent")
        editTrigger.send(())
    }

    func updateShape(_ shape: PillShapeModel?) {
        self.shape = shape
        recordEdit("shape")
        editTrigger.send(())
    }

    func updateFormulation(_ formulation: PillFormulationModel?) {
        self.formulation = formulation
        recordEdit("formulation")
        editTrigger.send(())
    }

    func updateImprint(front: PillFaceModel?, back: PillFaceModel?) {
        self.front = front
        self.back = back
        recordEdit("imprint")
        editTrigger.send(())
    }

    // MARK: - Fetch

    // 신규 검색(최초·속성 편집) — 첫 페이지부터 다시 조회하고 목록을 교체한다.
    private func fetchCandidates() {
        appendNextPage = false
        isLoadingMore = false
        nextCursor = nil
        hasNext = false
        searchingSubject.send(true)
        pillUseCase.fetchPillCandidates(
            colors: colors.isEmpty ? nil : colors,
            isTransparent: isTransparent,
            shape: shape,
            formulation: formulation,
            front: front,
            back: back,
            cursor: nil,
            size: 20
        )
    }

    // 다음 페이지 — 아래로 스크롤해 목록 끝에 다다르면 호출(VC willDisplay). 결과를 기존 목록에 이어 붙인다.
    // hasNext=false거나 이미 로딩 중이면 무시. 신규 검색과 달리 전체 로딩 상태(searching)로 전환하지 않는다.
    func loadMore() {
        guard hasNext, !isLoadingMore, let cursor = nextCursor else { return }
        isLoadingMore = true
        appendNextPage = true
        pillUseCase.fetchPillCandidates(
            colors: colors.isEmpty ? nil : colors,
            isTransparent: isTransparent,
            shape: shape,
            formulation: formulation,
            front: front,
            back: back,
            cursor: cursor,
            size: 20
        )
    }
}
