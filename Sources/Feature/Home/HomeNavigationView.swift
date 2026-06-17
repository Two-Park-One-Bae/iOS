import SwiftUI
import Shared

// MARK: - Home Navigation View

public struct HomeNavigationView: View {
    private let router: HomeRouter
    @State private var viewModel: HomeViewModel
    private let makeDetailViewModel: (String) -> DetailViewModel

    public init(
        router: HomeRouter,
        viewModel: HomeViewModel,
        makeDetailViewModel: @escaping (String) -> DetailViewModel
    ) {
        self.router = router
        self._viewModel = State(wrappedValue: viewModel)
        self.makeDetailViewModel = makeDetailViewModel
    }

    public var body: some View {
        @Bindable var router = router
        return NavigationStack(path: $router.path) {
            HomeView(viewModel: viewModel, router: router)
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .detail(let itemID):
                        DetailView(viewModel: makeDetailViewModel(itemID))
                    }
                }
        }
    }
}
