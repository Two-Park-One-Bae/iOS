import UIKit

import AuthFeature
import Core
import DSKit
import Domain

@main
final class AuthDemoAppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Login·Consent ViewModel 이 @Injected 로 AuthUseCase 를 받으므로 데모에서도 등록이 필요하다.
        // scenario 를 바꾸면 재방문(로그인 직후 홈)·약관 개정(저장 시 400 → 재조회) 흐름을 볼 수 있다.
        //
        // 약관 및 동의 화면의 저장 결과는 스킴 실행 인자로 고른다 (NM-548) —
        //   `-optionalSave bump`(400 → 재조회) · `-optionalSave fail`(실패 → 되돌림). 없으면 성공.
        let mock = MockAuthUseCase(scenario: .newUser, optionalSaveResult: Self.optionalSaveResult)
        DIContainer.shared.register(AuthUseCase.self) { mock }
        // ConsentViewModel 이 가입 이벤트(NM-547)를 보낼 곳. 데모에선 콘솔에만 찍는다.
        DIContainer.shared.register(AttributionTracking.self) { PrintAttribution() }
        return true
    }

    private static var optionalSaveResult: MockAuthUseCase.OptionalSaveResult {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-optionalSave"),
              arguments.indices.contains(index + 1) else {
            return .success
        }
        switch arguments[index + 1] {
        case "bump": return .versionBumped
        case "fail": return .failure
        default:     return .success
        }
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

/// Info.plist 가 SceneDelegate 를 선언하고 있어서, 이게 없으면 AppDelegate 가 만든 window 가
/// 무시되고 검은 화면만 뜬다(HomeFeatureDemo 와 같은 이유).
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var coordinator: AuthCoordinator?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController()
        window.makeKeyAndVisible()
        self.window = window

        startAuth()
    }

    /// 앱의 AppCoordinator 가 하는 일을 데모에서 최소한으로 흉내낸다 —
    /// 인증 흐름을 띄우고, 끝나면 홈 자리에 스텁 화면을 놓는다.
    private func startAuth() {
        guard let nav = window?.rootViewController as? UINavigationController else { return }

        let coordinator = AuthCoordinator(
            navigationController: nav,
            startAt: Self.startRoute,
            onFinished: { [weak self] in self?.showHomeStub() }
        )
        self.coordinator = coordinator
        coordinator.start()
    }

    /// 스킴 실행 인자로 시작 지점을 고른다 — 동의 시트만 보려고 매번 로그인을 탭하지 않아도 된다.
    ///
    ///   Product ▸ Scheme ▸ Edit Scheme ▸ Arguments ▸ `-startAt consent`
    ///
    /// 세션 복원 결과가 `.consent` 인 상태(로그인은 됐지만 미동의)를 그대로 재현한다.
    private static var startRoute: AuthRoute {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-startAt"),
              arguments.indices.contains(index + 1) else {
            return .login
        }
        return arguments[index + 1] == "consent" ? .consent : .login
    }

    private func showHomeStub() {
        guard let nav = window?.rootViewController as? UINavigationController else { return }
        let home = HomeStubViewController(
            onSignOut: { [weak self] in self?.startAuth() },
            onConsents: { [weak nav] in
                // 앱에서는 설정 탭 스택에 push 한다 — 데모는 홈 자리에서 바로 들어간다.
                nav?.pushViewController(AuthBuilder().makeConsentSettingsViewController(), animated: true)
            }
        )
        nav.setViewControllers([home], animated: true)
    }
}

/// 인증을 통과했을 때 도착하는 자리. 실제 홈 대신 로그아웃으로 되돌아가는 버튼만 둔다.
private final class HomeStubViewController: UIViewController {

    private let onSignOut: () -> Void
    private let onConsents: () -> Void

    init(onSignOut: @escaping () -> Void, onConsents: @escaping () -> Void) {
        self.onSignOut = onSignOut
        self.onConsents = onConsents
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DSColor.bgApp

        let label = UILabel()
        label.text = "홈 (Stub)"
        label.font = DSKitFontFamily.Pretendard.bold.font(size: 22)
        label.textColor = DSColor.textPrimary

        let caption = UILabel()
        caption.text = "인증을 통과했습니다"
        caption.font = DSKitFontFamily.Pretendard.regular.font(size: 14)
        caption.textColor = DSColor.textSecondary

        let signOutButton = SecondaryButton(title: "로그아웃")
        signOutButton.addAction(UIAction { [weak self] _ in self?.confirmSignOut() }, for: .touchUpInside)

        // 앱에서는 설정 > 약관 및 동의 행이다 (NM-548).
        let consentsButton = SecondaryButton(title: "약관 및 동의")
        consentsButton.addAction(UIAction { [weak self] _ in self?.onConsents() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [label, caption, consentsButton, signOutButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.setCustomSpacing(28, after: caption)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    /// 앱에서는 AppCoordinator 가 띄우는 다이얼로그다 — 데모에서도 같은 컴포넌트를 확인할 수 있게 둔다.
    private func confirmSignOut() {
        DSConfirmDialogView.present(
            on: view,
            title: "로그아웃할까요?",
            confirmTitle: "로그아웃",
            confirmed: { [weak self] in self?.onSignOut() }
        )
    }
}

private struct PrintAttribution: AttributionTracking {
    func signUp() { print("[Attribution] 가입") }
}
