import UIKit

import Core
import Domain
import HomeFeature

@main
final class HomeDemoAppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // HomeViewModel이 @Injected로 PillUseCase를 받으므로 데모에서도 등록이 필요하다.
        // remaining을 0으로 주면 한도 소진 표시(경고색)와 카드 탭 시 안내 팝업을 볼 수 있다.
        DIContainer.shared.register(PillUseCase.self) { MockPillUseCase(remaining: 12) }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

/// Info.plist가 SceneDelegate를 선언하고 있어서, 이게 없으면 AppDelegate가 만든 window가
/// 무시되고 검은 화면만 뜬다(기존 결함).
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let nav = UINavigationController()
        nav.viewControllers = [HomeVC(viewModel: HomeViewModel())]
        window.rootViewController = nav
        window.makeKeyAndVisible()
        self.window = window
    }
}
