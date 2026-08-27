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

    /// 카카오톡이 깔려 있으면 앱 전환 로그인, 아니면 웹 계정 로그인.
    /// 앱 전환은 사용자가 카카오톡에서 되돌아오지 않을 수 있어 실패 시 계정 로그인으로 폴백한다.
    @MainActor
    private func requestKakaoToken() async throws -> String {
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
