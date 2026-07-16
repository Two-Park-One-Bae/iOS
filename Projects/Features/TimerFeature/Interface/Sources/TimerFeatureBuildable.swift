import UIKit
import BaseFeatureDependency

public protocol TimerFeatureBuildable {
    func makeTimerCoordinator(navigationController: UINavigationController) -> CoordinatorProtocol
    // 설정 탭의 타이머 섹션 화면 (NM-308)
    func makeSettingsViewController() -> UIViewController
}
