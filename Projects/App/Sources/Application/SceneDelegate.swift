import UIKit
import BaseFeatureDependency
import Core
import Domain

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
