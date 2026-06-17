import Observation
import SwiftUI

// MARK: - Explore Router

@Observable
public final class ExploreRouter {
    public var path = NavigationPath()

    public init() {}

    public func navigate(to route: ExploreRoute) {
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
