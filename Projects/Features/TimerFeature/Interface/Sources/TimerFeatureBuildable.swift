import UIKit
import BaseFeatureDependency

public protocol TimerFeatureBuildable {
    func makeTimerCoordinator(navigationController: UINavigationController) -> CoordinatorProtocol
}
