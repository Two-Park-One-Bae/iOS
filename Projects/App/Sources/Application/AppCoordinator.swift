import UIKit
import BaseFeatureDependency
import HomeFeature

final class AppCoordinator: BaseCoordinator {
    override func start() {
        showHome()
    }

    private func showHome() {
        let homeCoordinator = HomeCoordinator(navigationController: navigationController)
        addChild(homeCoordinator)
        homeCoordinator.start()
    }
}
