import UIKit
import HomeFeatureInterface
import HomeFeature
import BaseFeatureDependency

final class HomeFeatureBuilder: HomeFeatureBuildable {
    func makeHomeCoordinator(navigationController: UINavigationController) -> CoordinatorProtocol {
        let coordinator = HomeCoordinator(navigationController: navigationController)
        return coordinator
    }
}
