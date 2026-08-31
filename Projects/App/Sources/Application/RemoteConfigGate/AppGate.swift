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

    private var updateObserver: NSObjectProtocol?

    init(windowScene: UIWindowScene?) {
        self.windowScene = windowScene

        // 게이트는 **떠 있는 동안에도** 값을 따라가야 한다. 점검을 끝냈는데 화면이 안 내려가거나,
        // 앱을 켜 둔 사용자에게 점검이 안 뜨면 원격 제어의 의미가 없다.
        // `evaluate()` 가 켜기·끄기 양방향을 처리하므로 갱신 때 그대로 다시 부르면 된다.
        updateObserver = NotificationCenter.default.addObserver(
            forName: .remoteConfigDidUpdate, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluate() }
        }
    }

    deinit {
        if let updateObserver { NotificationCenter.default.removeObserver(updateObserver) }
    }

    /// 최신 Remote Config 값으로 게이트 상태를 갱신한다.
    ///
    /// 여러 경로(앱 시작·포그라운드 복귀·실시간 리스너·장애 감지)에서 반복 호출되므로
    /// **몇 번을 불러도 안전해야 한다.** 상태가 그대로면 아무 일도 하지 않는다.
    func evaluate() {
        let rc = RemoteConfigService.shared
        let next: Kind? = rc.isForceUpdateRequired ? .forceUpdate
                        : rc.isUnderMaintenance ? .maintenance
                        : nil

        #if DEBUG
        // 호출 경로가 넷이라 **바뀔 때만** 찍는다. 매번 찍으면 정작 전환이 로그에 묻힌다.
        if next != current {
            print("🚧 AppGate — 강제업데이트 \(rc.isForceUpdateRequired) · 점검 \(rc.isUnderMaintenance)")
        }
        #endif

        switch next {
        case .forceUpdate: show(.forceUpdate) { ForceUpdateViewController(appStoreURL: rc.appStoreURL) }
        case .maintenance: show(.maintenance) { MaintenanceViewController(message: rc.maintenanceMessage) }
        case nil:          dismissGate()
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
