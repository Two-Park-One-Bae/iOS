import UIKit
import HomeFeature
import Domain

@main
final class HomeDemoAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let nav = UINavigationController()
        let viewModel = HomeViewModel(useCase: StubHomeUseCase())
        nav.viewControllers = [HomeVC(viewModel: viewModel)]
        window.rootViewController = nav
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

// Stub for Demo
struct StubHomeUseCase: HomeUseCaseProtocol {
    func fetchItems() -> AnyPublisher<[HomeEntity], Error> {
        Just([
            HomeEntity(id: 1, title: "샘플 아이템", description: "데모용 샘플입니다", imageURL: nil),
            HomeEntity(id: 2, title: "두 번째 아이템", description: "또 다른 샘플", imageURL: nil),
        ])
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }
    func fetchItem(id: Int) -> AnyPublisher<HomeEntity, Error> { Empty().eraseToAnyPublisher() }
}
