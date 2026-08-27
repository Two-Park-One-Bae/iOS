import Combine
import Foundation

import Domain

/// 인증 데모용 AuthUseCase 스텁.
///
/// 실제 소셜 SDK·서버를 타지 않는다 — UseCase 를 통째로 바꿔치우므로 카카오·Apple·Google
/// 어느 버튼을 눌러도 로그인 창 없이 바로 다음 화면으로 넘어간다. 화면과 흐름만 보는 용도다.
///
/// `scenario` 한 줄만 바꾸면 다른 흐름을 볼 수 있다.
final class MockAuthUseCase: AuthUseCase {

    enum Scenario {
        /// 신규 가입 — 로그인 → 약관 동의 → 홈
        case newUser
        /// 재방문 — 이미 동의한 회원이라 로그인 직후 홈
        case returningUser
        /// 약관 개정 — '동의하고 계속' 을 누르면 400 이 오고, 새 버전으로 화면이 다시 그려진다
        case consentBumped
    }

    let user = CurrentValueSubject<AuthUser?, Never>(nil)

    private let scenario: Scenario
    /// consentBumped 에서 첫 저장만 실패시키기 위한 플래그.
    private var didRejectOnce = false

    init(scenario: Scenario = .newUser) {
        self.scenario = scenario
    }

    func restoreSession() async -> AuthRoute {
        // 데모는 항상 로그인 화면에서 시작한다.
        .login
    }

    func signIn(with provider: AuthProvider) async throws -> AuthRoute {
        // 버튼 잠금과 인디케이터가 보이도록 잠깐 끈다.
        try? await Task.sleep(for: .milliseconds(600))
        user.send(AuthUser(
            userId: "demo-uid",
            provider: provider,
            providerUserId: "demo-\(provider.rawValue.lowercased())",
            consents: [],
            onboardingRequired: scenario != .returningUser
        ))
        return scenario == .returningUser ? .home : .consent
    }

    func fetchConsentDefinitions() async throws -> [ConsentDefinition] {
        try? await Task.sleep(for: .milliseconds(300))
        // 400 을 한 번 받은 뒤에는 올라간 버전으로 내려준다 — 화면이 새 버전으로 다시 그려지는 걸 확인할 수 있다.
        let version = didRejectOnce ? "2.0" : "1.0"
        return [
            ConsentDefinition(
                type: .terms,
                version: version,
                isRequired: true,
                policyUrl: URL(string: "https://www.apple.com/legal/privacy/kr/"),
                title: "이용약관"
            ),
            ConsentDefinition(
                type: .privacy,
                version: version,
                isRequired: true,
                policyUrl: URL(string: "https://policies.google.com/privacy?hl=ko"),
                title: "개인정보처리방침"
            ),
        ]
    }

    func agreeToConsents(_ definitions: [ConsentDefinition]) async throws -> AuthRoute {
        try? await Task.sleep(for: .milliseconds(400))

        if scenario == .consentBumped, !didRejectOnce {
            didRejectOnce = true
            throw AuthError.consentVersionMismatch
        }
        return .home
    }

    func signOut() {
        user.send(nil)
        NotificationCenter.default.post(name: .authDidSignOut, object: nil)
    }

    func deleteAccount() async throws {
        try? await Task.sleep(for: .milliseconds(400))
        signOut()
    }
}
