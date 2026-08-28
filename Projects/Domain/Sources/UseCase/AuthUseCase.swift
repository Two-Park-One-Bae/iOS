//
//  AuthUseCase.swift
//  Domain
//
//  Created by 바견규 on 8/28/26.
//

import Combine
import Foundation

public protocol AuthUseCase {

    /// 서버가 준 최신 회원 정보. 로그아웃·탈퇴 후에는 반드시 nil 이다(계정 스코프 캐시 폐기).
    var user: CurrentValueSubject<AuthUser?, Never> { get }

    /// 앱 실행·포그라운드 복귀 시 갈 화면을 정한다.
    func restoreSession() async -> AuthRoute

    /// 소셜 로그인 → 회원 조회 → 갈 화면. 취소·실패는 throw.
    func signIn(with provider: AuthProvider) async throws -> AuthRoute

    /// 동의 화면 재료. 400 재조회 경로에서도 같은 호출을 쓴다.
    func fetchConsentDefinitions() async throws -> [ConsentDefinition]

    /// 필수 동의 저장 → 갱신된 회원 기준으로 다음 화면을 정한다.
    func agreeToConsents(_ definitions: [ConsentDefinition]) async throws -> AuthRoute

    /// 로그아웃. 실패해도 로컬 상태는 비운다 — 화면에 이전 계정 정보가 남는 편이 더 나쁘다.
    func signOut()

    /// 탈퇴. 실패하면 **로그아웃하지 않고** throw 한다 — 계정이 남아 있는데 삭제됐다고 안내하지 않기 위함.
    func deleteAccount() async throws
}

public final class DefaultAuthUseCase: AuthUseCase {

    private let repository: AuthRepositoryProtocol

    public let user = CurrentValueSubject<AuthUser?, Never>(nil)

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - 진입 라우팅

    /*
     라우팅 표를 계산하는 유일한 자리 (spec: feature/auth/README.md §진입 라우팅).

       세션 없음                        → 로그인
       세션 있음 · onboardingRequired  → 동의 온보딩
       세션 있음 · 충족                 → 홈

     `/users/me` 조회가 실패하면 로그인으로 되돌린다. 동의 여부를 모르는 채 홈에 들여보내면
     "로그인됐지만 미동의" 라는, spec 이 없다고 못박은 상태가 화면에 생긴다.
     */
    public func restoreSession() async -> AuthRoute {
        guard repository.isSignedIn else {
            user.send(nil)
            return .login
        }

        do {
            return try await refreshUser()
        } catch {
            user.send(nil)
            return .login
        }
    }

    public func signIn(with provider: AuthProvider) async throws -> AuthRoute {
        try await repository.signIn(with: provider)
        // 최초 로그인이면 이 호출에서 서버가 회원을 만든다 — 별도 가입 단계가 없다.
        return try await refreshUser()
    }

    // MARK: - 동의

    public func fetchConsentDefinitions() async throws -> [ConsentDefinition] {
        try await repository.fetchConsentDefinitions()
    }

    public func agreeToConsents(_ definitions: [ConsentDefinition]) async throws -> AuthRoute {
        // 필수 항목 전체를 현재 버전 · agreed=true 로 한 번에 보낸다. 부분 저장은 없다.
        let agreements = definitions
            .filter(\.isRequired)
            .map { ConsentAgreement(type: $0.type, version: $0.version, agreed: true) }

        let updated = try await repository.saveConsents(agreements)
        user.send(updated)
        // 응답의 onboardingRequired 만 신뢰한다 — 저장에 성공했으니 충족됐다고 앱이 단정하지 않는다.
        return updated.onboardingRequired ? .consent : .home
    }

    // MARK: - 로그아웃 · 탈퇴

    public func signOut() {
        // signOut 이 던지는 경우는 사실상 없지만, 던지더라도 로컬 상태는 비운다.
        try? repository.signOut()
        clearAccountScopedState()
    }

    public func deleteAccount() async throws {
        // 실패하면 여기서 멈춘다 — clear 를 먼저 하면 삭제 실패인데도 로그아웃된 것처럼 보인다.
        try await repository.deleteAccount()
        try? repository.signOut()
        clearAccountScopedState()
    }

    // MARK: - Private

    private func refreshUser() async throws -> AuthRoute {
        let fetched = try await repository.fetchMe()
        user.send(fetched)
        return fetched.onboardingRequired ? .consent : .home
    }

    /// 계정에 딸린 값은 전부 버린다. 병동 공용 기기에서 앞사람의 잔여 횟수·동의 상태가 보이면 안 된다
    /// (spec: feature/auth/README.md §계정 스코프 캐시 폐기).
    ///
    /// 여기서 지우는 건 회원 정보뿐이고, 다른 UseCase 의 캐시(알약 잔여 횟수 등)는
    /// `.authDidSignOut` 을 받은 조립 지점이 지운다 — Domain 이 서로를 참조하지 않게 하기 위함.
    private func clearAccountScopedState() {
        user.send(nil)
        NotificationCenter.default.post(name: .authDidSignOut, object: nil)
    }
}
