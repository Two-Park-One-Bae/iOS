import Observation
import Shared

// MARK: - Home ViewModel

@Observable
public final class HomeViewModel {
    // MARK: - State
    public var state: ViewState<[Item]> = .idle

    // MARK: - Dependencies
    private let repository: ItemRepository

    // MARK: - Init
    public init(repository: ItemRepository) {
        self.repository = repository
    }

    // MARK: - Methods
    @MainActor
    public func loadItems() async {
        state = .loading
        do {
            let items = try await repository.fetchItems()
            state = .success(items)
        } catch {
            state = .failure(error)
        }
    }
}

// MARK: - Preview Mock

extension HomeViewModel {
    public static func mock() -> HomeViewModel {
        let vm = HomeViewModel(repository: MockItemRepository())
        vm.state = .success(Item.mocks)
        return vm
    }
}
