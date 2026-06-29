import UIKit
import BaseFeatureDependency
import HomeFeatureInterface
import DSKit

public final class TabBarCoordinator: CoordinatorProtocol {

    // MARK: - Properties

    public var navigationController: UINavigationController
    public var childCoordinators: [CoordinatorProtocol] = []

    private let homeBuilder: HomeFeatureBuildable
    private var tabBarVC: TabBarVC?

    // MARK: - Init

    public init(
        navigationController: UINavigationController,
        homeBuilder: HomeFeatureBuildable
    ) {
        self.navigationController = navigationController
        self.homeBuilder = homeBuilder
    }

    // MARK: - Start

    public func start() {
        let viewModel = TabBarViewModel()
        let tabBar = TabBarVC(viewModel: viewModel)
        self.tabBarVC = tabBar

        tabBar.viewControllers = makeTabViewControllers()
        configureAppearance(tabBar)

        navigationController.setViewControllers([tabBar], animated: false)
        navigationController.setNavigationBarHidden(true, animated: false)
    }

    // MARK: - Private

    private func makeTabViewControllers() -> [UIViewController] {
        let homeNav = UINavigationController()
        let homeCoordinator = homeBuilder.makeHomeCoordinator(navigationController: homeNav)
        homeCoordinator.start()
        addChild(homeCoordinator)
        homeNav.tabBarItem = UITabBarItem(title: "홈", image: DSIcon.house.uiImage, tag: 0)

        let taskNav = UINavigationController()
        taskNav.tabBarItem = UITabBarItem(title: "업무", image: DSIcon.clipboard.uiImage, tag: 1)

        let historyNav = UINavigationController()
        historyNav.tabBarItem = UITabBarItem(title: "기록", image: DSIcon.clock.uiImage, tag: 2)

        let settingsNav = UINavigationController()
        settingsNav.tabBarItem = UITabBarItem(title: "설정", image: DSIcon.settings.uiImage, tag: 3)

        return [homeNav, taskNav, historyNav, settingsNav]
    }

    private func configureAppearance(_ tabBar: UITabBarController) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white

        appearance.stackedLayoutAppearance.normal.iconColor = DSColor.Neutral._400
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: DSColor.Neutral._400]
        appearance.stackedLayoutAppearance.selected.iconColor = DSColor.Primary._500
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: DSColor.Primary._500]

        tabBar.tabBar.standardAppearance = appearance
        tabBar.tabBar.scrollEdgeAppearance = appearance
    }
}
