//
//  AuthService.swift
//  Networks
//
//  Created by 바견규 on 8/28/26.
//

import Foundation

// BaseService<AuthAPI>의 타입 별칭. DI 등록 시 DefaultAuthService.standard로 사용
public typealias DefaultAuthService = BaseService<AuthAPI>

// Repository가 의존할 프로토콜. 테스트 시 Mock으로 교체 가능
public protocol AuthService {
    /// 카카오 액세스 토큰 → Firebase Custom Token. 401 `KAKAO_TOKEN_INVALID` · 503 을 화면에서 가르므로
    /// 에러 코드를 보존하는 호출을 쓴다.
    func exchangeKakaoToken(_ accessToken: String) async throws -> KakaoTokenEntity
    func fetchConsentDefinitions() async throws -> [ConsentDefinitionEntity]
    func fetchMe() async throws -> UserEntity
    func saveConsents(_ agreements: [ConsentAgreementRequest]) async throws -> UserEntity
    /// 204. 500 이면 계정이 남아 있을 수 있어 상위가 **로그아웃하지 않고** 재시도한다.
    func deleteMe() async throws
}

extension DefaultAuthService: AuthService {

    public func exchangeKakaoToken(_ accessToken: String) async throws -> KakaoTokenEntity {
        try await requestObjectAsync(.kakaoToken(request: KakaoTokenRequest(kakaoAccessToken: accessToken)))
    }

    public func fetchConsentDefinitions() async throws -> [ConsentDefinitionEntity] {
        try await requestObjectAsync(.consents)
    }

    public func fetchMe() async throws -> UserEntity {
        try await requestObjectAsync(.me)
    }

    public func saveConsents(_ agreements: [ConsentAgreementRequest]) async throws -> UserEntity {
        try await requestObjectAsync(.saveConsents(request: ConsentAgreementsRequest(agreements: agreements)))
    }

    public func deleteMe() async throws {
        try await requestNoContentAsync(.deleteMe)
    }
}
