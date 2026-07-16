import UIKit
import BaseFeatureDependency
import TimerFeatureInterface

public final class TimerBuilder: TimerFeatureBuildable {

    public init() {}

    public func makeTimerCoordinator(navigationController: UINavigationController) -> CoordinatorProtocol {
        TimerCoordinator(navigationController: navigationController)
    }

    public func makeSettingsViewController() -> UIViewController {
        SettingsViewController()
    }
}
