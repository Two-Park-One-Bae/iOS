import Observation
import Shared
import Feature

// MARK: - DI Container

@Observable
final class AppDIContainer {
    // MARK: - Singletons
    private let networkClient: NetworkProviding
    private let itemRepository: ItemRepository

    // MARK: - Init
    init(
        networkClient: NetworkProviding? = nil,
        itemRepository: ItemRepository? = nil
    ) {
        let network = networkClient ?? NetworkClient()
        self.networkClient = network
        self.itemRepository = itemRepository ?? DefaultItemRepository(networkClient: network)
    }

    // MARK: - View Model Factory
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(repository: itemRepository)
    }

    func makeDetailViewModel(itemID: String) -> DetailViewModel {
        DetailViewModel(itemID: itemID, repository: itemRepository)
    }
}
