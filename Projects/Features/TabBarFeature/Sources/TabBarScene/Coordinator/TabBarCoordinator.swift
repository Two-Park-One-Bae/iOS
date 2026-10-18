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

    /// 설정 탭의 약관·계정 행 처리 (NM-548 · NM-410). 탭바는 인증을 모르고 그대로 전달만 한다.
    /// 약관 및 동의 화면은 설정 탭 스택에 push 한다 — 화면을 만드는 건 주입한 쪽이다.
    private let makeConsentSettings: () -> UIViewController
    private let onLogout: () -> Void
    private let onDeleteAccount: () -> Void

    // MARK: - Init

    public init(
        navigationController: UINavigationController,
        homeBuilder: HomeFeatureBuildable,
        timerBuilder: TimerFeatureBuildable,
        drugBuilder: DrugIdentificationFeatureBuildable,
        makeConsentSettings: @escaping () -> UIViewController,
        onLogout: @escaping () -> Void,
        onDeleteAccount: @escaping () -> Void
    ) {
        self.navigationController = navigationController
        self.homeBuilder = homeBuilder
        self.timerBuilder = timerBuilder
        self.drugBuilder = drugBuilder
        self.makeConsentSettings = makeConsentSettings
        self.onLogout = onLogout
        self.onDeleteAccount = onDeleteAccount
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
        pillNav.tabBarItem = UITabBarItem(title: "알약", image: DSIcon.pill.uiImage, tag: 1)

        let timerNav = UINavigationController()
        let timerCoordinator = timerBuilder.makeTimerCoordinator(navigationController: timerNav)
        timerCoordinator.start()
        addChild(timerCoordinator)
        timerNav.tabBarItem = UITabBarItem(title: "타이머", image: DSIcon.timer.uiImage, tag: 2)

        let settingsNav = UINavigationController()
        let settingsVC = timerBuilder.makeSettingsViewController(
            onConsents: { [weak settingsNav, makeConsentSettings = self.makeConsentSettings] in
                settingsNav?.pushViewController(makeConsentSettings(), animated: true)
            },
            onLogout: onLogout,
            onDeleteAccount: onDeleteAccount
        )
        settingsNav.setViewControllers([settingsVC], animated: false)
        settingsNav.setNavigationBarHidden(true, animated: false)
        settingsNav.tabBarItem = UITabBarItem(title: "설정", image: DSIcon.settings.uiImage, tag: 3)

        return [homeNav, pillNav, timerNav, settingsNav]
    }

    private func configureAppearance(_ tabBar: UITabBarController) {
        // V2.1.0: 탭 바는 iOS 기본 모양을 쓴다 — 배경을 칠하지 않아 iOS 26 에서는 떠 있는 유리 탭 바가 된다
        // (spec: design/README.md "탭 바의 선택 표시는 iOS 기본 모양"). 색만 디자인에 맞춘다.
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        appearance.stackedLayoutAppearance.normal.iconColor = DSColor.textTertiary
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: DSColor.textTertiary]
        appearance.stackedLayoutAppearance.selected.iconColor = DSColor.Primary._500
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: DSColor.Primary._500]

        tabBar.tabBar.standardAppearance = appearance
        tabBar.tabBar.scrollEdgeAppearance = appearance
    }
}
