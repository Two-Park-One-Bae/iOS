import SwiftUI
import Shared

// MARK: - Main Tab View

public struct MainTabView: View {
    @State private var appRouter: AppRouter
    private let homeViewModel: HomeViewModel
    private let makeDetailViewModel: (String) -> DetailViewModel

    public init(
        appRouter: AppRouter,
        homeViewModel: HomeViewModel,
        makeDetailViewModel: @escaping (String) -> DetailViewModel
    ) {
        self._appRouter = State(wrappedValue: appRouter)
        self.homeViewModel = homeViewModel
        self.makeDetailViewModel = makeDetailViewModel
    }

    public var body: some View {
        TabView(selection: $appRouter.selectedTab) {
            HomeNavigationView(
                router: appRouter.home,
                viewModel: homeViewModel,
                makeDetailViewModel: makeDetailViewModel
            )
            .tabItem {
                Label {
                    Text(MainTab.home.title)
                } icon: {
                    Image(appIcon: MainTab.home.icon)
                }
            }
            .tag(MainTab.home)

            ExploreNavigationView(router: appRouter.explore)
                .tabItem {
                    Label {
                        Text(MainTab.explore.title)
                    } icon: {
                        Image(appIcon: MainTab.explore.icon)
                    }
                }
                .tag(MainTab.explore)

            SettingsNavigationView(router: appRouter.settings)
                .tabItem {
                    Label {
                        Text(MainTab.settings.title)
                    } icon: {
                        Image(appIcon: MainTab.settings.icon)
                    }
                }
                .tag(MainTab.settings)
        }
        .task {
            // 메인 진입 — 콜드스타트로 보류된 딥링크가 있으면 적용
            appRouter.flushPendingLink()
        }
    }
}
