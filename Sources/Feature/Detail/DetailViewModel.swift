import Observation
import Shared

// MARK: - Detail ViewModel

@Observable
public final class DetailViewModel {
    // MARK: - State
    public var state: ViewState<Item> = .idle

    // MARK: - Properties
    private let itemID: String

    // MARK: - Dependencies
    private let repository: ItemRepository

    // MARK: - Init
    public init(itemID: String, repository: ItemRepository) {
        self.itemID = itemID
        self.repository = repository
    }

    // MARK: - Methods
    @MainActor
    public func loadDetail() async {
        state = .loading
        do {
            let detail = try await repository.fetchItem(id: itemID)
            state = .success(detail)
        } catch {
            state = .failure(error)
        }
    }
}

// MARK: - Preview Mock

extension DetailViewModel {
    public static func mock(item: Item = .mocks[0]) -> DetailViewModel {
        let vm = DetailViewModel(itemID: item.id, repository: MockItemRepository())
        vm.state = .success(item)
        return vm
    }
}
