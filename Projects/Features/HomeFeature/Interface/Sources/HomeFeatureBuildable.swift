import UIKit
import BaseFeatureDependency

public protocol HomeFeatureBuildable {
    func makeHomeCoordinator(navigationController: UINavigationController) -> CoordinatorProtocol
}
