import UIKit
import TabBarFeature
import BaseFeatureDependency
import DrugIdentificationFeatureInterface
import HomeFeatureInterface
import TimerFeatureInterface

@main
final class TabBarDemoAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let nav = UINavigationController()

        // 데모는 탭 구성만 확인하는 용도라 각 탭을 빈 화면 스텁으로 채운다.
        let coordinator = TabBarCoordinator(
            navigationController: nav,
            homeBuilder: StubHomeFeatureBuilder(),
            timerBuilder: StubTimerFeatureBuilder(),
            drugBuilder: StubDrugIdentificationFeatureBuilder(),
            onLogout: {},
            onDeleteAccount: {}
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
        StubCoordinator.pushing("홈 (Stub)", into: navigationController)
    }
}

final class StubTimerFeatureBuilder: TimerFeatureBuildable {
    func makeTimerCoordinator(navigationController: UINavigationController) -> CoordinatorProtocol {
        StubCoordinator.pushing("타이머 (Stub)", into: navigationController)
    }

    func makeSettingsViewController(
        onLogout: @escaping () -> Void,
        onDeleteAccount: @escaping () -> Void
    ) -> UIViewController {
        StubCoordinator.makeViewController("설정 (Stub)")
    }
}

final class StubDrugIdentificationFeatureBuilder: DrugIdentificationFeatureBuildable {
    func makeDrugIdentificationCoordinator(navigationController: UINavigationController) -> CoordinatorProtocol {
        StubCoordinator.pushing("알약 (Stub)", into: navigationController)
    }
}

final class StubCoordinator: CoordinatorProtocol {
    var navigationController: UINavigationController
    var childCoordinators: [CoordinatorProtocol] = []

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {}

    static func makeViewController(_ title: String) -> UIViewController {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .systemBackground
        viewController.title = title
        return viewController
    }

    static func pushing(_ title: String, into navigationController: UINavigationController) -> CoordinatorProtocol {
        navigationController.setViewControllers([makeViewController(title)], animated: false)
        return StubCoordinator(navigationController: navigationController)
    }
}
