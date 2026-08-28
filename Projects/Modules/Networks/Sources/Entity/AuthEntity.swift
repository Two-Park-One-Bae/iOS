//
//  AuthEntity.swift
//  Networks
//
//  Created by 바견규 on 8/28/26.
//

import Foundation

/// POST /api/v0/auth/kakao/token 200 응답.
public struct KakaoTokenEntity: Decodable {
    public let firebaseCustomToken: String
}

/// GET /api/v0/users/me · POST /api/v0/users/me/consents 200 응답 (openapi `User`).
public struct UserEntity: Decodable {
    /// 회원 식별자 = Firebase UID.
    public let userId: String
    /// GOOGLE · APPLE · KAKAO. 서버가 enum 을 늘려도 앱이 깨지지 않도록 원문 문자열로 받는다.
    public let provider: String
    public let providerUserId: String
    public let createdAt: String
    public let consents: [ConsentStatusEntity]
    /// 필수 동의 미충족 여부. **화면 분기의 유일한 근거** — 클라이언트가 consents 로 재계산하지 않는다.
    public let onboardingRequired: Bool
}

/// `User.consents` 원소 (openapi `ConsentStatus`).
public struct ConsentStatusEntity: Decodable {
    public let type: String
    public let agreed: Bool
    /// 동의한 문서 버전. 미동의면 null.
    public let version: String?
    /// 현재 필수 버전 충족 여부(동의 & 최신 버전).
    public let satisfied: Bool
}

/// GET /api/v0/consents 200 응답 원소 (openapi `ConsentDefinition`).
///
/// 항목·버전·문서 URL 은 **서버 소유**다. 앱은 이 값으로 동의 화면을 그리고 버전을 하드코딩하지 않는다
/// (spec: domains/auth.md §동의).
public struct ConsentDefinitionEntity: Decodable {
    public let type: String
    public let version: String
    public let required: Bool
    public let policyUrl: String
    /// 표시용 항목명(예: "이용약관").
    public let title: String
}
