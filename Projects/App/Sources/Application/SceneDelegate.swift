import UIKit
import SwiftUI
import BaseFeatureDependency
import Core
import Domain
import TimerFeature

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var appCoordinator: AppCoordinator?

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

        // 콜드런치 시 위젯 딥링크 처리 (start() 이후여야 .openTimerTab 옵저버가 잡힘)
        handle(url: connectionOptions.urlContexts.first?.url)
    }

    // 위젯 "+" 딥링크(nursemate://timer/preset/pick) — 앱 열려 있을 때
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
        } else {
            NotificationCenter.default.post(name: .openTimerTab, object: nil)
        }
    }

    private func presentWidgetOnboarding() {
        guard let top = topMostViewController() else { return }
        let host = UIHostingController(rootView: WidgetOnboardingView())
        top.present(host, animated: true)
    }

    // 런처 위젯 → 전체 프리셋 목록에서 골라 즉시 시작(앱이 열려 있으니 UseCase로 정식 시작·알람 예약).
    private func presentQuickStart() {
        guard let top = topMostViewController() else { return }
        let useCase = DIContainer.shared.resolve(TimerUseCase.self)
        let view = TimerQuickStartPickerView(presets: useCase.presets.value) { preset in
            useCase.start(preset: preset)
        }
        top.present(UIHostingController(rootView: view), animated: true)
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
    }
}
