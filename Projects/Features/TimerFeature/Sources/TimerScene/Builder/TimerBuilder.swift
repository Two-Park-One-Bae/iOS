import UIKit
import BaseFeatureDependency
import TimerFeatureInterface

public final class TimerBuilder: TimerFeatureBuildable {

    public init() {}

    public func makeTimerCoordinator(navigationController: UINavigationController) -> CoordinatorProtocol {
        TimerCoordinator(navigationController: navigationController)
    }

    public func makeSettingsViewController(
        onConsents: @escaping () -> Void,
        onLogout: @escaping () -> Void,
        onDeleteAccount: @escaping () -> Void
    ) -> UIViewController {
        let viewController = SettingsViewController()
        viewController.onConsentsTapped = onConsents
        viewController.onLogoutTapped = onLogout
        viewController.onDeleteAccountTapped = onDeleteAccount
        return viewController
    }
}
