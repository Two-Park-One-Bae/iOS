import SwiftUI

// MARK: - Explore Navigation View

public struct ExploreNavigationView: View {
    private let router: ExploreRouter

    public init(router: ExploreRouter) {
        self.router = router
    }

    public var body: some View {
        @Bindable var router = router
        return NavigationStack(path: $router.path) {
            ExploreView()
                .navigationDestination(for: ExploreRoute.self) { _ in }
        }
    }
}
