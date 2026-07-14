import UIKit
import Core

// Remote Config 값에 따라 앱 전체를 덮는 차단 화면(강제 업데이트 / 점검)을 관리한다.
// 별도의 최상위 UIWindow 로 띄워 어떤 화면 위에서도 확실히 덮고 상호작용을 막는다.
// 우선순위: 강제 업데이트 > 점검 모드.
@MainActor
final class AppGate {

    private weak var windowScene: UIWindowScene?
    private var gateWindow: UIWindow?

    /// 현재 떠 있는 게이트 종류(중복 present·불필요한 재생성 방지).
    private enum Kind: Equatable { case forceUpdate, maintenance }
    private var current: Kind?

    init(windowScene: UIWindowScene?) {
        self.windowScene = windowScene
    }

    /// 최신 Remote Config 값으로 게이트 상태를 갱신한다.
    func evaluate() {
        let rc = RemoteConfigService.shared
        if rc.isForceUpdateRequired {
            show(.forceUpdate) { ForceUpdateViewController(appStoreURL: rc.appStoreURL) }
        } else if rc.isUnderMaintenance {
            show(.maintenance) { MaintenanceViewController(message: rc.maintenanceMessage) }
        } else {
            dismissGate()
        }
    }

    private func show(_ kind: Kind, _ make: () -> UIViewController) {
        guard current != kind else { return }   // 이미 같은 게이트면 유지
        guard let windowScene else { return }

        let window = gateWindow ?? UIWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1
        window.rootViewController = make()
        window.makeKeyAndVisible()
        gateWindow = window
        current = kind
    }

    private func dismissGate() {
        guard current != nil else { return }
        gateWindow?.isHidden = true
        gateWindow = nil
        current = nil
    }
}
