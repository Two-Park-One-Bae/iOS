import Combine
import Moya
import CombineMoya

public protocol HomeAPIServiceProtocol {
    func fetchItems() -> AnyPublisher<HomeListResponseDTO, Error>
    func fetchItem(id: Int) -> AnyPublisher<HomeItemDTO, Error>
}

public final class DefaultHomeAPIService: HomeAPIServiceProtocol {
    private let provider = MoyaProvider<HomeAPI>()

    public init() {}

    public func fetchItems() -> AnyPublisher<HomeListResponseDTO, Error> {
        provider.requestPublisher(.getItems)
            .map(HomeListResponseDTO.self)
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }

    public func fetchItem(id: Int) -> AnyPublisher<HomeItemDTO, Error> {
        provider.requestPublisher(.getItemDetail(id: id))
            .map(HomeItemDTO.self)
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
}
