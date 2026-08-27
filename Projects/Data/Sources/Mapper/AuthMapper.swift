//
//  AuthMapper.swift
//  Data
//
//  Created by 바견규 on 8/28/26.
//

import Foundation

import Domain
import Networks

// MARK: - 회원

extension UserEntity {
    /// 모르는 `provider`(예: 후속 확장될 네이버)는 실패로 올린다 — 임의 기본값으로 눌러 담으면
    /// 회원이 다른 공급자로 보이게 되고, 그 값은 되돌릴 수 없다.
    func toDomain() throws -> AuthUser {
        guard let provider = AuthProvider(rawValue: provider) else {
            throw AuthError.unknown
        }

        return AuthUser(
            userId: userId,
            provider: provider,
            providerUserId: providerUserId,
            // 모르는 ConsentType 은 조용히 버린다 — 서버가 항목을 늘려도 앱이 깨지지 않는다.
            // 화면 게이트는 consents 가 아니라 onboardingRequired 로 하므로 안전하다.
            consents: consents.compactMap { $0.toDomain() },
            onboardingRequired: onboardingRequired
        )
    }
}

extension ConsentStatusEntity {
    func toDomain() -> ConsentStatus? {
        guard let type = ConsentType(rawValue: type) else { return nil }
        return ConsentStatus(type: type, agreed: agreed, version: version, satisfied: satisfied)
    }
}

// MARK: - 동의 정의

extension ConsentDefinitionEntity {
    func toDomain() -> ConsentDefinition? {
        guard let type = ConsentType(rawValue: type) else { return nil }
        return ConsentDefinition(
            type: type,
            version: version,
            isRequired: required,
            policyUrl: URL(string: policyUrl),
            title: title
        )
    }
}

extension ConsentAgreement {
    func toRequest() -> ConsentAgreementRequest {
        ConsentAgreementRequest(type: type.rawValue, version: version, agreed: agreed)
    }
}
