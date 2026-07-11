import UIKit
import HomeFeature

@main
final class HomeDemoAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
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
