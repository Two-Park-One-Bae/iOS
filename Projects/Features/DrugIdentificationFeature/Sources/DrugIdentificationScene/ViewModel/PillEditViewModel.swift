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
    }

    // MARK: - Dependencies

    @Injected private var pillUseCase: PillUseCase

    // MARK: - Immutable

    let pillIndex: Int
    let thumbnail: UIImage?

    // MARK: - Editable Attribute State

    private(set) var colors: [PillColorModel]
    private(set) var isTransparent: Bool
    private(set) var shape: PillShapeModel?
    private(set) var formulation: PillFormulationModel?
    private(set) var front: PillFaceModel?
    private(set) var back: PillFaceModel?

    // MARK: - Streams

    private let candidatesSubject = CurrentValueSubject<[PillCandidateModel], Never>([])
    private var didLoad = false
    private var cancelBag = Set<AnyCancellable>()

    // MARK: - Init

    init(pillIndex: Int, attribute: PillAttributeModel, thumbnail: UIImage?) {
        self.pillIndex = pillIndex
        self.thumbnail = thumbnail
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
                self?.candidatesSubject.send(page.candidates)
            }
            .store(in: &cancelBag)

        input.viewDidLoad
            .sink { [weak self] in
                guard let self, !self.didLoad else { return }
                self.didLoad = true
                self.fetchCandidates()
            }
            .store(in: &cancelBag)

        let isEmpty = candidatesSubject
            .map { $0.isEmpty }
            .eraseToAnyPublisher()

        return Output(
            candidates: candidatesSubject.eraseToAnyPublisher(),
            isEmpty: isEmpty
        )
    }

    // MARK: - Edits (변경 시 실시간 재조회)

    func updateColors(_ colors: [PillColorModel]) {
        self.colors = colors
        fetchCandidates()
    }

    func setTransparent(_ isTransparent: Bool) {
        self.isTransparent = isTransparent
        fetchCandidates()
    }

    func updateShape(_ shape: PillShapeModel?) {
        self.shape = shape
        fetchCandidates()
    }

    func updateFormulation(_ formulation: PillFormulationModel?) {
        self.formulation = formulation
        fetchCandidates()
    }

    func updateImprint(front: PillFaceModel?, back: PillFaceModel?) {
        self.front = front
        self.back = back
        fetchCandidates()
    }

    // MARK: - Fetch

    private func fetchCandidates() {
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
}
