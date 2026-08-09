import Foundation

public final class TabBarViewModel {

    // MARK: - Tab

    public enum Tab: Int {
        case home = 0
        case task = 1
        case history = 2
        case settings = 3
    }

    // MARK: - Callbacks (set by Coordinator)

    public var onTabSelected: ((Tab) -> Void)?

    // MARK: - State

    private(set) public var selectedTab: Tab = .home

    public init() {}

    // MARK: - Methods

    public func selectTab(_ tab: Tab) {
        selectedTab = tab
        onTabSelected?(tab)
    }
}
