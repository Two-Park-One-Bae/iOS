import UIKit
import BaseFeatureDependency
import Core
import Domain
import TimerFeature

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var appCoordinator: AppCoordinator?
    private var pendingURL: URL?   // 콜드런치 딥링크 — 창이 준비된 활성화 시점에 처리
    private var appGate: AppGate?  // Remote Config 차단 화면(강제 업데이트·점검)

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        let navigationController = UINavigationController()
        appCoordinator = AppCoordinator(navigationController: navigationController)
        appCoordinator?.start()

        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        appGate = AppGate(windowScene: windowScene)

        // 콜드런치 딥링크는 저장만 — 창이 활성화된 sceneDidBecomeActive 에서 present.
        pendingURL = connectionOptions.urlContexts.first?.url
    }

    // 위젯 딥링크 — 앱 열려 있을 때(warm)는 바로 처리.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        handle(url: URLContexts.first?.url)
    }

    // NM-302 위젯 딥링크: /widget/howto → 설정 온보딩, /quickstart → 빠른 시작, 그 외 → 타이머 탭.
    private func handle(url: URL?) {
        guard let url, url.scheme == "nursemate", url.host == "timer" else { return }
        if url.path.contains("howto") {
            presentWidgetOnboarding()
        } else if url.path.contains("quickstart") {
            presentQuickStart()
        } else if url.path.contains("/start") {
            startPreset(from: url)
        } else {
            NotificationCenter.default.post(name: .openTimerTab, object: nil)
        }
    }

    // 설정형 위젯(26.1 미만) → 지정 프리셋을 정식 시작(Live Activity + 알림).
    private func startPreset(from url: URL) {
        guard let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "preset" })?.value,
              let id = UUID(uuidString: raw) else { return }
        let useCase = DIContainer.shared.resolve(TimerUseCase.self)
        guard let preset = useCase.presets.value.first(where: { $0.id == id }) else { return }
        useCase.start(preset: preset)
    }

    private func presentWidgetOnboarding() {
        present(WidgetOnboardingViewController())
    }

    // 런처 위젯 → 전체 프리셋 목록에서 골라 즉시 시작(앱이 열려 있으니 UseCase로 정식 시작·알람 예약).
    private func presentQuickStart() {
        let useCase = DIContainer.shared.resolve(TimerUseCase.self)
        let picker = TimerQuickStartPickerViewController(presets: useCase.presets.value) { preset in
            useCase.start(preset: preset)
        }
        present(picker)
    }

    private func present(_ viewController: UIViewController) {
        guard let top = topMostViewController() else { return }
        top.present(UINavigationController(rootViewController: viewController), animated: true)
    }

    private func topMostViewController() -> UIViewController? {
        guard var top = window?.rootViewController else { return nil }
        while let presented = top.presentedViewController { top = presented }
        return top
    }

    // 백그라운드에서 만료된 타이머의 RINGING 전이를 앱 복귀 즉시 반영
    // (endAt 기반이라 잔여시간 복원은 자동 — NM-276 QA 규칙)
    func sceneDidBecomeActive(_ scene: UIScene) {
        let useCase = DIContainer.shared.resolve(TimerUseCase.self)
        // App Intent(AlarmKit)가 App Group 저장소를 직접 바꿨을 수 있음 — 먼저 재동기화.
        useCase.reload()
        useCase.refresh()

        // Remote Config 최신값 fetch 후 강제 업데이트/점검 게이트 갱신(포그라운드 복귀 포함).
        Task { @MainActor in
            await RemoteConfigService.shared.fetchAndActivate()
            appGate?.evaluate()
        }

        // 콜드런치 딥링크: 창이 활성화된 지금 present.
        if let url = pendingURL {
            pendingURL = nil
            handle(url: url)
        }
    }
}
