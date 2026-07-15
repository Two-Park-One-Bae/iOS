import UIKit
import BaseFeatureDependency
import HomeFeatureInterface
import TimerFeatureInterface
import DrugIdentificationFeatureInterface
import DSKit

public final class TabBarCoordinator: CoordinatorProtocol {

    // MARK: - Properties

    public var navigationController: UINavigationController
    public var childCoordinators: [CoordinatorProtocol] = []

    private let homeBuilder: HomeFeatureBuildable
    private let timerBuilder: TimerFeatureBuildable
    private let drugBuilder: DrugIdentificationFeatureBuildable
    private var tabBarVC: TabBarVC?

    // MARK: - Init

    public init(
        navigationController: UINavigationController,
        homeBuilder: HomeFeatureBuildable,
        timerBuilder: TimerFeatureBuildable,
        drugBuilder: DrugIdentificationFeatureBuildable
    ) {
        self.navigationController = navigationController
        self.homeBuilder = homeBuilder
        self.timerBuilder = timerBuilder
        self.drugBuilder = drugBuilder
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

    // MARK: - Public

    /// 홈 탭으로 전환 (예: 촬영 취소 후 복귀)
    public func switchToHomeTab() {
        tabBarVC?.selectedIndex = 0
    }

    /// 알람 탭 랜딩 = C1 (spec) — 타이머 탭으로 전환
    public func switchToTimerTab() {
        tabBarVC?.selectedIndex = 2
    }

    /// 약물 식별 — 알약 탭으로 전환
    public func switchToPillTab() {
        tabBarVC?.selectedIndex = 1
        // 프로그래밍 방식 전환은 tabBarController(didSelect:)를 트리거하지 않으므로 직접 알림.
        NotificationCenter.default.post(name: .pillTabSelected, object: nil)
    }

    // MARK: - Private

    // 탭 구성 (디자인): 홈 / 알약 / 타이머 / 설정
    private func makeTabViewControllers() -> [UIViewController] {
        let homeNav = UINavigationController()
        let homeCoordinator = homeBuilder.makeHomeCoordinator(navigationController: homeNav)
        homeCoordinator.start()
        addChild(homeCoordinator)
        homeNav.tabBarItem = UITabBarItem(title: "홈", image: DSIcon.house.uiImage, tag: 0)

        let pillNav = UINavigationController()
        let pillCoordinator = drugBuilder.makeDrugIdentificationCoordinator(navigationController: pillNav)
        pillCoordinator.start()
        addChild(pillCoordinator)
        pillNav.tabBarItem = UITabBarItem(title: "알약", image: UIImage(systemName: "pills"), tag: 1)

        let timerNav = UINavigationController()
        let timerCoordinator = timerBuilder.makeTimerCoordinator(navigationController: timerNav)
        timerCoordinator.start()
        addChild(timerCoordinator)
        timerNav.tabBarItem = UITabBarItem(title: "타이머", image: UIImage(systemName: "timer"), tag: 2)

        let settingsNav = UINavigationController()
        settingsNav.tabBarItem = UITabBarItem(title: "설정", image: DSIcon.settings.uiImage, tag: 3)

        return [homeNav, pillNav, timerNav, settingsNav]
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
