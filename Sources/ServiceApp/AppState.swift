import Foundation
import Shared

// MARK: - App Phase

enum AppPhase {
    case splash
    case onboarding
    case auth
    case maintenance
    case main
}

// MARK: - App State

@Observable
final class AppState {
    var currentPhase: AppPhase = .splash

    private let userDefaults: UserDefaultsStore

    init(userDefaults: UserDefaultsStore = .shared) {
        self.userDefaults = userDefaults
    }

    @MainActor
    func determineInitialPhase() async {
        // 스플래시 최소 표시 시간
        try? await Task.sleep(for: .seconds(1))

        if userDefaults.hasCompletedOnboarding {
            currentPhase = .main
        } else {
            currentPhase = .onboarding
        }
    }

    func completeOnboarding() {
        userDefaults.hasCompletedOnboarding = true
        currentPhase = .main
    }

    func enterMaintenance() {
        currentPhase = .maintenance
    }

    func exitMaintenance() {
        currentPhase = .main
    }
}
