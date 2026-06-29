import UIKit
import TabBarFeature
import HomeFeatureInterface
import BaseFeatureDependency

@main
final class TabBarDemoAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let nav = UINavigationController()

        let coordinator = TabBarCoordinator(
            navigationController: nav,
            homeBuilder: StubHomeFeatureBuilder()
        )
        coordinator.start()

        window.rootViewController = nav
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

// MARK: - Stub

final class StubHomeFeatureBuilder: HomeFeatureBuildable {
    func makeHomeCoordinator(navigationController: UINavigationController) -> CoordinatorProtocol {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        vc.title = "홈 (Stub)"
        navigationController.setViewControllers([vc], animated: false)
        return StubCoordinator(navigationController: navigationController)
    }
}

final class StubCoordinator: CoordinatorProtocol {
    var navigationController: UINavigationController
    var childCoordinators: [CoordinatorProtocol] = []

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {}
}
