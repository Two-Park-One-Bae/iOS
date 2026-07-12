import UIKit
import BaseFeatureDependency
import TabBarFeature
import TimerFeature
import HomeFeature
import DrugIdentificationFeature

final class AppCoordinator: BaseCoordinator {

    private var tabBarCoordinator: TabBarCoordinator?

    override func start() {
        showTabBar()
        observeTabSwitching()
    }

    private func showTabBar() {
        let tabBarCoordinator = TabBarCoordinator(
            navigationController: navigationController,
            homeBuilder: HomeFeatureBuilder(),
            timerBuilder: TimerBuilder(),
            drugBuilder: DrugIdentificationBuilder()
        )
        self.tabBarCoordinator = tabBarCoordinator
        addChild(tabBarCoordinator)
        tabBarCoordinator.start()
    }

    // 탭 전환 진입점: 알람 랜딩(.openTimerTab) + 홈 버튼(.selectTimerTab/.selectPillTab)
    private func observeTabSwitching() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: .openTimerTab, object: nil, queue: .main) { [weak self] _ in
            self?.tabBarCoordinator?.switchToTimerTab()
        }
        nc.addObserver(forName: .selectTimerTab, object: nil, queue: .main) { [weak self] _ in
            self?.tabBarCoordinator?.switchToTimerTab()
        }
        nc.addObserver(forName: .selectPillTab, object: nil, queue: .main) { [weak self] _ in
            self?.tabBarCoordinator?.switchToPillTab()
        }
    }
}
