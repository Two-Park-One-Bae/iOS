//
//  AppleSignInProvider.swift
//  Data
//
//  Created by 바견규 on 8/28/26.
//

import AuthenticationServices
import CryptoKit
import UIKit

import Core
import Domain

/// 애플 로그인 — Firebase 네이티브 공급자.
///
/// 외부 SDK 없이 AuthenticationServices 로 ID 토큰을 받아 Firebase 에 넘긴다.
/// Apple 심사에서 소셜 로그인이 있으면 사실상 필수인 공급자다.
struct AppleSignInProvider: SocialSignInProviding {

    func signIn() async throws {
        /*
         nonce 는 두 벌로 쓰인다.
           - Apple 요청에는 SHA256 **해시**를 넣고
           - Firebase 에는 해시 전 **원문**을 넘긴다

         Firebase 가 "내가 방금 만든 요청의 응답이 맞는지"를 이 쌍으로 확인해 재생 공격을 막는다.
         둘을 바꿔 넣으면 서명은 멀쩡한데 검증만 실패해서 원인을 찾기 어렵다.
         */
        let rawNonce = Self.randomNonce()
        let credential = try await requestCredential(hashedNonce: Self.sha256(rawNonce))

        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.unknown
        }

        // fullName 은 **최초 1회만** 내려온다. 지금은 저장하지 않지만, Firebase 가 프로필에 채울 수 있도록 넘긴다.
        try await FirebaseAuthService.signInWithApple(
            idToken: idToken,
            rawNonce: rawNonce,
            fullName: credential.fullName
        )
    }

    @MainActor
    private func requestCredential(hashedNonce: String) async throws -> ASAuthorizationAppleIDCredential {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        let controller = ASAuthorizationController(authorizationRequests: [request])

        return try await withCheckedThrowingContinuation { continuation in
            // 델리게이트는 weak 참조라 지역 변수로 두면 즉시 해제돼 콜백이 오지 않는다.
            // 콜백 클로저가 자기 자신을 강하게 잡고, 완료 시점에 놓아준다.
            let delegate = AppleSignInDelegate(continuation: continuation)
            delegate.retain()
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            controller.performRequests()
        }
    }

    // MARK: - Nonce

    /// 암호학적 난수 기반 nonce. Apple 문서 권장 방식(허용 문자 집합에서 균등 추출).
    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""

        while result.count < length {
            var random: UInt8 = 0
            // 실패는 SecRandom 이 엔트로피를 못 얻은 상태 — 여기서 임의 값으로 대체하면 nonce 의 의미가 사라진다.
            guard SecRandomCopyBytes(kSecRandomDefault, 1, &random) == errSecSuccess else {
                continue
            }
            // 256 을 charset 크기로 나눈 나머지 구간은 버린다 — 그대로 % 하면 앞쪽 문자가 더 자주 뽑힌다.
            if random < (255 - (255 % UInt8(charset.count))) {
                result.append(charset[Int(random) % charset.count])
            }
        }

        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - Delegate

/// ASAuthorizationController 의 콜백을 continuation 하나로 접는다.
///
/// 성공·실패 어느 쪽이든 **정확히 한 번만** resume 해야 하므로 `finish(_:)` 한 곳으로 모았다.
private final class AppleSignInDelegate: NSObject {

    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private var selfReference: AppleSignInDelegate?

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func retain() {
        selfReference = self
    }

    private func finish(_ result: Result<ASAuthorizationAppleIDCredential, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        selfReference = nil
    }
}

extension AppleSignInDelegate: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(.failure(AuthError.unknown))
            return
        }
        finish(.success(credential))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // 사용자가 시트를 닫은 것은 오류가 아니다 — 안내 없이 로그인 화면에 머문다.
        if let error = error as? ASAuthorizationError, error.code == .canceled {
            finish(.failure(AuthError.cancelled))
            return
        }
        finish(.failure(AuthError.unknown))
    }
}

extension AppleSignInDelegate: ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            PresentationAnchor.topMostViewController()?.view.window ?? ASPresentationAnchor()
        }
    }
}
