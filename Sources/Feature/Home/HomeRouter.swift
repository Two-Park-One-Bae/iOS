import Observation
import SwiftUI

// MARK: - Home Router

@Observable
public final class HomeRouter {
    public var path = NavigationPath()

    public init() {}

    public func navigate(to route: HomeRoute) {
        path.append(route)
    }

    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    public func popToRoot() {
        path = NavigationPath()
    }
}
