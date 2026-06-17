import SwiftUI
import Feature
import Shared

// MARK: - Root View

struct RootView: View {
    @State private var appState: AppState
    private let appRouter: AppRouter
    private let diContainer: AppDIContainer

    init(appState: AppState, appRouter: AppRouter, diContainer: AppDIContainer) {
        self._appState = State(wrappedValue: appState)
        self.appRouter = appRouter
        self.diContainer = diContainer
    }

    var body: some View {
        Group {
            switch appState.currentPhase {
            case .splash:
                SplashView()
            case .onboarding:
                OnboardingView(appState: appState)
            case .auth:
                AuthView()
            case .maintenance:
                MaintenanceView()
            case .main:
                MainTabView(
                    appRouter: appRouter,
                    homeViewModel: diContainer.makeHomeViewModel(),
                    makeDetailViewModel: { itemID in
                        diContainer.makeDetailViewModel(itemID: itemID)
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.currentPhase)
        .task {
            await appState.determineInitialPhase()
        }
    }
}
