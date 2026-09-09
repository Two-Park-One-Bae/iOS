//
//  KakaoSignInProvider.swift
//  Data
//
//  Created by 바견규 on 8/28/26.
//

import UIKit

import Core
import Domain
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser
import Networks

/// 카카오 로그인 — Firebase 비네이티브 공급자.
///
/// 카카오에서 받은 액세스 토큰을 **서버가 검증**한 뒤 Firebase Custom Token 을 발급한다.
/// 앱이 직접 Firebase 로 갈 수 없는 이유이자, 다른 앱에서 발급된 카카오 토큰으로 사칭하는 걸 막는 지점이다
/// (spec: domains/auth.md §소셜 로그인).
///
///   카카오 로그인 → 액세스 토큰 → POST /auth/kakao/token → firebaseCustomToken → Firebase 로그인
struct KakaoSignInProvider: SocialSignInProviding {

    /// 카카오계정 대표 이메일 동의항목. 서버가 이 권한이 실린 액세스 토큰으로 사용자 정보를 조회해
    /// 이메일을 Firebase 레코드에 채운다 (spec: domains/auth.md 인증 §카카오).
    private static let emailScope = "account_email"

    private let service: AuthService

    init(service: AuthService) {
        self.service = service
    }

    func signIn() async throws {
        let kakaoAccessToken = try await requestKakaoToken()

        do {
            let exchanged = try await service.exchangeKakaoToken(kakaoAccessToken)
            try await FirebaseAuthService.signIn(withCustomToken: exchanged.firebaseCustomToken)
        } catch {
            // 401 KAKAO_TOKEN_INVALID · 503(다른 방법으로 로그인 안내)을 화면에서 갈라야 한다.
            throw AuthErrorMapper.map(error)
        }
    }

    @MainActor
    private func requestKakaoToken() async throws -> String {
        let token = try await authorize()
        // 서버가 이 토큰으로 이메일을 조회한다 — 권한이 빠져 있으면 값을 받지 못한다.
        return await tokenWithEmailScope(token)
    }

    /// 카카오톡이 깔려 있으면 앱 전환 로그인, 아니면 웹 계정 로그인.
    /// 앱 전환은 사용자가 카카오톡에서 되돌아오지 않을 수 있어 실패 시 계정 로그인으로 폴백한다.
    @MainActor
    private func authorize() async throws -> String {
        if UserApi.isKakaoTalkLoginAvailable() {
            do {
                return try await login { UserApi.shared.loginWithKakaoTalk(completion: $0) }
            } catch AuthError.cancelled {
                // 사용자가 직접 취소한 것 — 폴백으로 창을 한 번 더 띄우지 않는다.
                throw AuthError.cancelled
            } catch {
                return try await login { UserApi.shared.loginWithKakaoAccount(completion: $0) }
            }
        }
        return try await login { UserApi.shared.loginWithKakaoAccount(completion: $0) }
    }

    /// 액세스 토큰에 이메일 권한을 실어 준다 (spec: domains/auth.md 인증 §카카오).
    ///
    /// 구글·애플은 Firebase 가 로그인을 처리해 이메일이 자동으로 들어가지만 카카오는 커스텀 토큰이라
    /// 비어 있다 — 콘솔에서 카카오 회원을 계정으로 구분할 방법이 이것뿐이라 서버가 채운다.
    /// iOS SDK 의 로그인 메서드는 scope 인자를 받지 않으므로(동의항목은 카카오 콘솔이 정한다),
    /// 이미 받은 토큰에 **추가 동의**를 붙이는 길만 있다.
    ///
    /// 콘솔에 필수 동의로 걸려 있어 보통은 로그인 시점에 이미 동의돼 있고 이 창은 뜨지 않는다.
    /// 설정이 바뀌었거나 동의 이력이 어긋난 계정에서만 한 번 더 받는다.
    ///
    /// **실패해도 로그인을 막지 않는다** — 이메일은 로그인의 성립 조건이 아니라는 게 계약이고
    /// (서버도 조회에 실패하면 이메일 없이 커스텀 토큰을 발급한다), 추가 동의를 취소하면
    /// 원래 토큰 그대로 진행한다.
    @MainActor
    private func tokenWithEmailScope(_ accessToken: String) async -> String {
        guard await isEmailScopeMissing() else { return accessToken }

        let reissued = try? await login {
            UserApi.shared.loginWithKakaoAccount(scopes: [Self.emailScope], completion: $0)
        }
        return reissued ?? accessToken
    }

    /// 이 토큰에 이메일 동의항목이 빠져 있는지.
    ///
    /// **판단이 서지 않으면 false 다** — 이미 권한이 있는데 동의 창을 한 번 더 띄우는 쪽이,
    /// 이메일을 못 받는 것보다 사용자에게 나쁘다. `using` 이 false 면 앱이 쓰지 않는 항목이라
    /// 추가 동의를 요청해도 오류만 난다.
    @MainActor
    private func isEmailScopeMissing() async -> Bool {
        await withCheckedContinuation { continuation in
            UserApi.shared.scopes(scopes: [Self.emailScope]) { info, _ in
                let scope = info?.scopes?.first { $0.id == Self.emailScope }
                continuation.resume(returning: scope?.using == true && scope?.agreed == false)
            }
        }
    }

    /// **반드시 메인 액터에 머물러야 한다.** `nonisolated` 로 두면 호출부가 `@MainActor` 여도
    /// async 함수가 메인을 벗어나 실행돼, 카카오 SDK 가 백그라운드에서 키 윈도우를 찾고
    /// `UIApplication.open` 을 부른다(Main Thread Checker 경고).
    @MainActor
    private func login(
        _ perform: (@escaping (OAuthToken?, Error?) -> Void) -> Void
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            perform { token, error in
                if let error {
                    continuation.resume(throwing: Self.mapSDKError(error))
                    return
                }
                guard let token else {
                    continuation.resume(throwing: AuthError.unknown)
                    return
                }
                continuation.resume(returning: token.accessToken)
            }
        }
    }

    /// 카카오 SDK 의 "사용자가 취소함" 만 골라낸다 — 나머지는 일반 오류로 안내한다.
    private static func mapSDKError(_ error: Error) -> AuthError {
        guard let sdkError = error as? SdkError, sdkError.isClientFailed else { return .unknown }
        if case .Cancelled = sdkError.getClientError().reason { return .cancelled }
        return .unknown
    }
}
