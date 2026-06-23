import Combine

public protocol HomeRepositoryProtocol {
    func fetchItems() -> AnyPublisher<[HomeEntity], Error>
    func fetchItem(id: Int) -> AnyPublisher<HomeEntity, Error>
}
