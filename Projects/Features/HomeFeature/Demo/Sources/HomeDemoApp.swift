import UIKit

import Core
import Domain
import HomeFeature

@main
final class HomeDemoAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // HomeViewModel이 @Injected로 PillUseCase를 받으므로 데모에서도 등록이 필요하다.
        DIContainer.shared.register(PillUseCase.self) { MockPillUseCase() }

        let window = UIWindow(frame: UIScreen.main.bounds)
        let nav = UINavigationController()
        let viewModel = HomeViewModel()
        nav.viewControllers = [HomeVC(viewModel: viewModel)]
        window.rootViewController = nav
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
