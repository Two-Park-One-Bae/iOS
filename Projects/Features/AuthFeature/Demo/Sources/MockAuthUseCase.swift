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

    /// 약관 및 동의 화면의 `저장` 결과 (NM-548).
    enum OptionalSaveResult {
        case success
        /// 그 사이 서버가 버전을 올렸다 — 400 → 재조회. 첫 저장만 실패한다.
        case versionBumped
        /// 서버 오류 — 안내 후 체크가 되돌아간다.
        case failure
    }

    let user = CurrentValueSubject<AuthUser?, Never>(nil)

    private let scenario: Scenario
    private let optionalSaveResult: OptionalSaveResult
    /// consentBumped · versionBumped 에서 첫 저장만 실패시키기 위한 플래그.
    private var didRejectOnce = false

    init(scenario: Scenario = .newUser, optionalSaveResult: OptionalSaveResult = .success) {
        self.scenario = scenario
        self.optionalSaveResult = optionalSaveResult
    }

    func restoreSession() async throws -> AuthRoute {
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
        // 실제 문서는 아직 웹에 게시되지 않았다(BE 가 GET /consents 로 내려줄 값).
        // 남의 약관을 가리키면 연결이 된 것처럼 보여 더 헷갈리므로, 우리 도메인의 예정 경로를 둔다 —
        // 지금 열면 404 지만 '보기'가 실제로 사파리를 띄우는지는 확인할 수 있다.
        return [
            ConsentDefinition(
                type: .terms,
                version: version,
                isRequired: true,
                policyUrl: URL(string: "https://nursemate.app/policy/terms"),
                title: "이용약관"
            ),
            ConsentDefinition(
                type: .privacy,
                version: version,
                isRequired: true,
                policyUrl: URL(string: "https://nursemate.app/policy/privacy"),
                title: "개인정보처리방침"
            ),
            ConsentDefinition(
                type: .overseas,
                version: version,
                isRequired: false,
                policyUrl: URL(string: "https://nursemate.app/privacy/overseas/"),
                title: "개인정보 국외 이전 및 제3자 제공"
            ),
        ]
    }

    func agreeToConsents(_ definitions: [ConsentDefinition], checked: Set<ConsentType>) async throws -> AuthRoute {
        try? await Task.sleep(for: .milliseconds(400))

        if scenario == .consentBumped, !didRejectOnce {
            didRejectOnce = true
            throw AuthError.consentVersionMismatch
        }
        // 서버처럼 응답한 대로 회원 상태를 남긴다 — 약관 및 동의 화면이 이 값으로 시작한다.
        apply(definitions.map {
            ConsentAgreement(type: $0.type, version: $0.version, agreed: $0.isRequired || checked.contains($0.type))
        })
        print("[Consent] 저장 — 체크: \(checked.map(\.rawValue).sorted())")
        return .home
    }

    func updateOptionalConsents(_ changes: [ConsentAgreement]) async throws {
        try? await Task.sleep(for: .milliseconds(400))

        switch optionalSaveResult {
        case .versionBumped where !didRejectOnce:
            didRejectOnce = true
            throw AuthError.consentVersionMismatch
        case .failure:
            throw AuthError.serverError
        default:
            apply(changes)
            print("[Consent] 선택 동의 변경 — \(changes.map { "\($0.type.rawValue)=\($0.agreed)" })")
        }
    }

    /// 보낸 항목만 바꾼다 — 서버의 `POST /users/me/consents` 와 같다.
    private func apply(_ agreements: [ConsentAgreement]) {
        guard let current = user.value else { return }
        var consents = current.consents.filter { status in !agreements.contains { $0.type == status.type } }
        consents += agreements.map {
            ConsentStatus(type: $0.type, agreed: $0.agreed, version: $0.version, satisfied: $0.agreed)
        }
        user.send(AuthUser(
            userId: current.userId,
            provider: current.provider,
            providerUserId: current.providerUserId,
            consents: consents,
            onboardingRequired: false
        ))
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
