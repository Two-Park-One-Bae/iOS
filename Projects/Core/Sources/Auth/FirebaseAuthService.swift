//
//  FirebaseAuthService.swift
//  Core
//
//  Created by 바견규 on 8/28/26.
//

import Foundation

import FirebaseAuth

/// Firebase Auth 래퍼 (NM-410).
///
/// 서버는 **자체 세션·JWT 를 발급하지 않는다.** Firebase ID 토큰을 그대로 검증하고 `uid` 를 회원 식별자로
/// 쓰므로(spec: domains/auth.md §인증), 클라이언트의 "세션"은 곧 Firebase 세션이다.
/// 토큰 저장·만료 전 자동 갱신은 Firebase SDK 가 하고, 여기서는 그걸 앱 계층에 노출하는 얇은 면만 담당한다.
///
/// FirebaseAuth 타입(`AuthCredential` 등)이 상위 계층으로 새지 않도록, 공급자별 로그인을
/// **원시 토큰을 받는 메서드**로 감쌌다 — Data 의 소셜 공급자 구현이 FirebaseAuth 를 import 하지 않아도 된다.
public enum FirebaseAuthService {

    /// 현재 로그인된 회원의 Firebase UID. 서버의 `userId` 와 같은 값이다.
    public static var currentUID: String? {
        Auth.auth().currentUser?.uid
    }

    /// 세션 복원 여부. 진입 라우팅의 첫 번째 판정 값이다(spec: feature/auth/README.md §진입 라우팅).
    public static var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }

    /// 인증 요청에 붙일 ID 토큰. 로그인 상태가 아니면 nil.
    ///
    /// - Parameter forceRefresh: 401 을 받은 뒤 1회 재시도할 때만 `true`.
    ///   평소에는 `false` — SDK 가 만료 전 알아서 갱신하므로 매번 강제 갱신하면 불필요한 네트워크가 는다.
    public static func idToken(forceRefresh: Bool = false) async throws -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        return try await user.getIDToken(forcingRefresh: forceRefresh)
    }

    // MARK: - 로그인

    /// 구글 — Firebase 네이티브 공급자. GoogleSignIn SDK 가 준 토큰으로 credential 을 만들어 로그인한다.
    public static func signInWithGoogle(idToken: String, accessToken: String) async throws {
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        try await Auth.auth().signIn(with: credential)
    }

    /// 애플 — Firebase 네이티브 공급자.
    ///
    /// `rawNonce` 는 ASAuthorization 요청에 넣은 nonce 의 **해시 전 원문**이다. 요청엔 SHA256 해시를 넣고
    /// 여기엔 원문을 넘겨야 Firebase 가 재생 공격(replay)을 걸러낸다 — 둘을 바꿔 넣으면 검증에 실패한다.
    public static func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: rawNonce,
            fullName: fullName
        )
        try await Auth.auth().signIn(with: credential)
    }

    /// 카카오 — Firebase 비네이티브라 서버가 발급한 Custom Token 으로 로그인한다.
    /// 결과물은 구글·애플과 같은 Firebase ID 토큰이라 이후 흐름이 동일하다(spec: domains/auth.md §소셜 로그인).
    public static func signIn(withCustomToken token: String) async throws {
        try await Auth.auth().signIn(withCustomToken: token)
    }

    // MARK: - 로그아웃

    /// 로컬 세션만 끊는다. 서버 상태는 건드리지 않으므로 탈퇴와는 별개다.
    public static func signOut() throws {
        try Auth.auth().signOut()
    }
}
