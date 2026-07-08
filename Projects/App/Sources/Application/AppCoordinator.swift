import UIKit
import BaseFeatureDependency
import TabBarFeature
import TimerFeature

final class AppCoordinator: BaseCoordinator {

    private var tabBarCoordinator: TabBarCoordinator?

    override func start() {
        showTabBar()
        observeTimerLanding()
    }

    private func showTabBar() {
        let tabBarCoordinator = TabBarCoordinator(
            navigationController: navigationController,
            homeBuilder: HomeFeatureBuilder(),
            timerBuilder: TimerBuilder()
        )
        self.tabBarCoordinator = tabBarCoordinator
        addChild(tabBarCoordinator)
        tabBarCoordinator.start()
    }

    // 알람 본문 탭 → C1 타이머 탭 랜딩 (spec)
    private func observeTimerLanding() {
        NotificationCenter.default.addObserver(
            forName: .openTimerTab,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.tabBarCoordinator?.switchToTimerTab()
        }
    }
}
