import SwiftUI

// MARK: - Settings Navigation View

public struct SettingsNavigationView: View {
    private let router: SettingsRouter

    public init(router: SettingsRouter) {
        self.router = router
    }

    public var body: some View {
        @Bindable var router = router
        return NavigationStack(path: $router.path) {
            SettingsView()
                .navigationDestination(for: SettingsRoute.self) { _ in }
        }
    }
}
