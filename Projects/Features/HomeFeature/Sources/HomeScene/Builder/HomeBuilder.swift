import UIKit
import HomeFeatureInterface
import BaseFeatureDependency

public final class HomeBuilder: HomeFeatureBuildable {

    public init() {}

    public func makeHomeCoordinator(navigationController: UINavigationController) -> CoordinatorProtocol {
        HomeCoordinator(navigationController: navigationController)
    }
}
