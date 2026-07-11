import Combine

public final class HomeViewModel {

    // MARK: - Navigation Callbacks (set by Coordinator)

    public var onDrugIdentifyTapped: (() -> Void)?
    public var onTreatmentTimerTapped: (() -> Void)?

    // MARK: - Input / Output

    public struct Input {
        public let viewDidLoad: AnyPublisher<Void, Never>
        public let drugIdentifyTapped: AnyPublisher<Void, Never>
        public let treatmentTimerTapped: AnyPublisher<Void, Never>

        public init(
            viewDidLoad: AnyPublisher<Void, Never>,
            drugIdentifyTapped: AnyPublisher<Void, Never>,
            treatmentTimerTapped: AnyPublisher<Void, Never>
        ) {
            self.viewDidLoad = viewDidLoad
            self.drugIdentifyTapped = drugIdentifyTapped
            self.treatmentTimerTapped = treatmentTimerTapped
        }
    }

    public struct Output {
        public let isLoading: AnyPublisher<Bool, Never>
        public let error: AnyPublisher<String, Never>
    }

    private var cancelBag = Set<AnyCancellable>()

    public init() {}

    public func transform(input: Input) -> Output {
        let isLoading = PassthroughSubject<Bool, Never>()
        let error = PassthroughSubject<String, Never>()

        input.drugIdentifyTapped
            .sink { [weak self] in self?.onDrugIdentifyTapped?() }
            .store(in: &cancelBag)

        input.treatmentTimerTapped
            .sink { [weak self] in self?.onTreatmentTimerTapped?() }
            .store(in: &cancelBag)

        return Output(
            isLoading: isLoading.eraseToAnyPublisher(),
            error: error.eraseToAnyPublisher()
        )
    }
}
