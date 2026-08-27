import UIKit
import BaseFeatureDependency

public protocol TimerFeatureBuildable {
    func makeTimerCoordinator(navigationController: UINavigationController) -> CoordinatorProtocol
    /// 설정 탭 화면 (NM-308 타이머 · NM-410 계정).
    ///
    /// 계정 행의 실제 처리는 인증을 아는 쪽(App)이 클로저로 주입한다 — TimerFeature 는 Auth 를 참조하지 않는다.
    func makeSettingsViewController(
        onLogout: @escaping () -> Void,
        onDeleteAccount: @escaping () -> Void
    ) -> UIViewController
}
