//
//  AuthRepositoryInterface.swift
//  Domain
//
//  Created by 바견규 on 8/28/26.
//

import Foundation

/// 회원·인증·동의 (NM-410).
///
/// 소셜 SDK(Google·Apple·Kakao)와 Firebase Auth 는 전부 이 프로토콜 뒤에 있다 —
/// UseCase·화면은 "어떤 SDK 로 로그인하는지" 를 모른다.
public protocol AuthRepositoryProtocol {

    /// Firebase 세션 복원 여부. 진입 라우팅의 첫 판정 값.
    var isSignedIn: Bool { get }

    /// 소셜 로그인 → Firebase 로그인까지 한 번에. 성공하면 이후 요청에 Bearer 가 붙는다.
    ///
    /// 사용자가 로그인 시트를 닫으면 `AuthError.cancelled` 로 실패한다 — 화면은 이걸 오류로 안내하지 않는다.
    func signIn(with provider: AuthProvider) async throws

    /// 회원 정보 + 동의 상태. 최초 인증이면 서버가 회원을 생성(upsert)한다 — 별도 가입 호출이 없다.
    func fetchMe() async throws -> AuthUser

    /// 동의 화면을 그릴 항목·버전·문서 URL. 인증 불필요(로그인 전에도 부를 수 있다).
    func fetchConsentDefinitions() async throws -> [ConsentDefinition]

    /// 필수 항목 **전체**를 한 번에 저장하고 갱신된 회원 정보를 받는다.
    /// 버전 불일치(400)는 `AuthError.consentVersionMismatch` 로 올라온다.
    func saveConsents(_ agreements: [ConsentAgreement]) async throws -> AuthUser

    /// 로컬 Firebase 세션만 끊는다.
    func signOut() throws

    /// 회원·동의·userId 로 묶인 데이터·Firebase 사용자를 삭제한다(Apple 심사 필수 요건).
    /// 멱등이라 재시도가 안전하다. 실패는 `AuthError.accountDeletionFailed`.
    func deleteAccount() async throws
}
