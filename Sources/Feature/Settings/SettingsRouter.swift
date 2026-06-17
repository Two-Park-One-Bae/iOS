import Observation
import SwiftUI

// MARK: - Settings Router

@Observable
public final class SettingsRouter {
    public var path = NavigationPath()

    public init() {}

    public func navigate(to route: SettingsRoute) {
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
