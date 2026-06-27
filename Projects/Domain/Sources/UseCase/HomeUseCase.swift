import Combine

public protocol HomeUseCaseProtocol {
    func fetchItems() -> AnyPublisher<[HomeEntity], Error>
    func fetchItem(id: Int) -> AnyPublisher<HomeEntity, Error>
}

public final class DefaultHomeUseCase: HomeUseCaseProtocol {
    private let repository: HomeRepositoryProtocol

    public init(repository: HomeRepositoryProtocol) {
        self.repository = repository
    }

    public func fetchItems() -> AnyPublisher<[HomeEntity], Error> {
        repository.fetchItems()
    }

    public func fetchItem(id: Int) -> AnyPublisher<HomeEntity, Error> {
        repository.fetchItem(id: id)
    }
}
