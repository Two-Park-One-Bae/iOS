import UIKit
import BaseFeatureDependency
import TabBarFeature

final class AppCoordinator: BaseCoordinator {
    override func start() {
        showTabBar()
    }

    private func showTabBar() {
        let tabBarCoordinator = TabBarCoordinator(
            navigationController: navigationController,
            homeBuilder: HomeFeatureBuilder()
        )
        addChild(tabBarCoordinator)
        tabBarCoordinator.start()
    }
}
