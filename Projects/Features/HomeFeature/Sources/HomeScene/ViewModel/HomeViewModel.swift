import Combine
import Domain

public final class HomeViewModel {
    public struct Input {
        public let viewDidLoad: AnyPublisher<Void, Never>
        public let itemSelected: AnyPublisher<Int, Never>
        public init(viewDidLoad: AnyPublisher<Void, Never>, itemSelected: AnyPublisher<Int, Never>) {
            self.viewDidLoad = viewDidLoad
            self.itemSelected = itemSelected
        }
    }

    public struct Output {
        public let items: AnyPublisher<[HomeEntity], Never>
        public let isLoading: AnyPublisher<Bool, Never>
        public let error: AnyPublisher<String, Never>
    }

    private let useCase: HomeUseCaseProtocol
    private var cancelBag = Set<AnyCancellable>()

    public init(useCase: HomeUseCaseProtocol) {
        self.useCase = useCase
    }

    public func transform(input: Input) -> Output {
        let items = PassthroughSubject<[HomeEntity], Never>()
        let isLoading = PassthroughSubject<Bool, Never>()
        let error = PassthroughSubject<String, Never>()

        input.viewDidLoad
            .handleEvents(receiveOutput: { _ in isLoading.send(true) })
            .flatMap { [weak self] _ -> AnyPublisher<[HomeEntity], Never> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return self.useCase.fetchItems()
                    .catch { err -> AnyPublisher<[HomeEntity], Never> in
                        error.send(err.localizedDescription)
                        return Just([]).eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .handleEvents(receiveOutput: { _ in isLoading.send(false) })
            .sink { items.send($0) }
            .store(in: &cancelBag)

        return Output(
            items: items.eraseToAnyPublisher(),
            isLoading: isLoading.eraseToAnyPublisher(),
            error: error.eraseToAnyPublisher()
        )
    }
}
