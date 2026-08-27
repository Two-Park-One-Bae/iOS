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
            policyUrl: Self.webURL(from: policyUrl),
            title: title
        )
    }

    /// 웹에서 열 수 있는 URL 만 통과시킨다.
    ///
    /// `URL(string:)` 은 스킴 없는 문자열("nursemate.app/terms")도 nil 이 아닌 URL 로 만들어 주기 때문에
    /// 존재 검사만으로는 걸러지지 않는다. 그대로 `SFSafariViewController` 에 넘기면 http·https 가 아닌
    /// URL 에서 예외가 나 앱이 죽는다 — 값의 출처가 서버라, 동의 정의에 오타 하나면 모든 사용자가
    /// 반드시 지나는 화면에서 크래시한다. 여기서 잘라 화면에는 '보기'를 감춘다.
    private static func webURL(from raw: String) -> URL? {
        guard let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }
}

extension ConsentAgreement {
    func toRequest() -> ConsentAgreementRequest {
        ConsentAgreementRequest(type: type.rawValue, version: version, agreed: agreed)
    }
}
