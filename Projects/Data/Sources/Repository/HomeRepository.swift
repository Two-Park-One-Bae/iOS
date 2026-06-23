import Combine
import Domain
import Networks

public final class HomeRepository: HomeRepositoryProtocol {
    private let service: HomeAPIServiceProtocol

    public init(service: HomeAPIServiceProtocol) {
        self.service = service
    }

    public func fetchItems() -> AnyPublisher<[HomeEntity], Error> {
        service.fetchItems()
            .map { $0.items.map { $0.toDomain() } }
            .eraseToAnyPublisher()
    }

    public func fetchItem(id: Int) -> AnyPublisher<HomeEntity, Error> {
        service.fetchItem(id: id)
            .map { $0.toDomain() }
            .eraseToAnyPublisher()
    }
}
