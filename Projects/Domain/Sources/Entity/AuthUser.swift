//
//  AuthUser.swift
//  Domain
//
//  Created by 바견규 on 8/28/26.
//

import Foundation

// MARK: - 회원

/// 로그인된 회원 (spec: domains/auth.md §회원).
///
/// 별도 회원가입 단계가 없다 — 소셜 로그인 최초 성공 시 서버가 생성(upsert)하고, 검증된 토큰이 곧 회원이다.
public struct AuthUser: Equatable {
    /// 회원 식별자 = Firebase UID.
    public let userId: String
    public let provider: AuthProvider
    public let providerUserId: String
    public let consents: [ConsentStatus]
    /// 필수 동의 미충족 여부. **서버 값만 신뢰한다** — 클라이언트가 consents 로 다시 계산하지 않는다.
    public let onboardingRequired: Bool

    public init(
        userId: String,
        provider: AuthProvider,
        providerUserId: String,
        consents: [ConsentStatus],
        onboardingRequired: Bool
    ) {
        self.userId = userId
        self.provider = provider
        self.providerUserId = providerUserId
        self.consents = consents
        self.onboardingRequired = onboardingRequired
    }
}

public extension AuthUser {

    /// 약관 **개정**으로 다시 묻는 것인지 — 예전 버전에 동의한 기록이 있는데 지금은 미충족.
    ///
    /// 최초 가입자와 갈라 **안내 문구만** 정하는 값이다. 화면 게이트는 그대로
    /// `onboardingRequired`(서버 값)가 쥔다 — "클라이언트가 consents 로 다시 계산하지 않는다"는
    /// 규칙(spec: domains/auth.md §동의)은 그 게이트에 대한 것이고, 여기서 그걸 다시 세지 않는다.
    /// 이 값이 틀려도 잘못된 문구가 나갈 뿐, 들여보낼 사람을 막거나 막을 사람을 들이지 않는다.
    ///
    /// `agreed && !satisfied` = "동의는 했는데 그 버전이 현재 필수 버전이 아니다" = 개정.
    /// 한 번도 동의한 적 없는 항목은 `agreed == false` 라 걸리지 않는다.
    var needsReconsent: Bool {
        consents.contains { $0.agreed && !$0.satisfied }
    }
}

/// 로그인 공급자. 계정 연결(account-linking)이 없어 같은 사람이라도 공급자가 다르면 별개 회원이다.
public enum AuthProvider: String, CaseIterable, Equatable {
    case google = "GOOGLE"
    case apple  = "APPLE"
    case kakao  = "KAKAO"
}

// MARK: - 동의

public enum ConsentType: String, Equatable {
    case terms   = "TERMS"
    case privacy = "PRIVACY"
}

/// 회원별 동의 상태 (`User.consents`).
public struct ConsentStatus: Equatable {
    public let type: ConsentType
    public let agreed: Bool
    /// 동의한 문서 버전. 미동의면 nil.
    public let version: String?
    /// 현재 필수 버전 충족 여부(동의 & 최신 버전).
    public let satisfied: Bool

    public init(type: ConsentType, agreed: Bool, version: String?, satisfied: Bool) {
        self.type = type
        self.agreed = agreed
        self.version = version
        self.satisfied = satisfied
    }
}

/// 동의 화면을 그리는 재료. 항목·버전·문서 URL 은 전부 서버가 소유한다 — 버전을 하드코딩하지 않는다.
public struct ConsentDefinition: Equatable {
    public let type: ConsentType
    public let version: String
    public let isRequired: Bool
    public let policyUrl: URL?
    /// 표시용 항목명(예: "이용약관").
    public let title: String

    public init(type: ConsentType, version: String, isRequired: Bool, policyUrl: URL?, title: String) {
        self.type = type
        self.version = version
        self.isRequired = isRequired
        self.policyUrl = policyUrl
        self.title = title
    }
}

/// 저장할 동의 한 건.
public struct ConsentAgreement: Equatable {
    public let type: ConsentType
    public let version: String
    public let agreed: Bool

    public init(type: ConsentType, version: String, agreed: Bool) {
        self.type = type
        self.version = version
        self.agreed = agreed
    }
}

// MARK: - 진입 라우팅

/// 앱 실행·로그인 직후 갈 화면. 아래 두 값만으로 정해지고 중간의 애매한 상태가 없다
/// (spec: feature/auth/README.md §진입 라우팅).
///
/// | 인증 세션 | onboardingRequired | 화면 |
/// |---|---|---|
/// | 없음 | — | `.login` |
/// | 있음 | true | `.consent` |
/// | 있음 | false | `.home` |
public enum AuthRoute: Equatable {
    case login
    case consent
    case home
}

// MARK: - 에러

/// 화면이 서로 다르게 반응해야 하는 인증 실패만 추린다. 나머지는 `.unknown` 으로 모아 일반 오류 안내를 띄운다.
public enum AuthError: Error, Equatable {
    /// 사용자가 소셜 로그인 시트를 닫았다. **오류가 아니다** — 아무 안내도 띄우지 않고 조용히 되돌아간다.
    case cancelled
    /// 401 `KAKAO_TOKEN_INVALID` — 카카오 재로그인 유도.
    case kakaoTokenInvalid
    /// 503 — Firebase·카카오 일시 장애. **세션을 유지**하고 재시도만 안내한다(로그아웃 사유가 아니다).
    case serviceUnavailable
    /// 500 `INTERNAL_ERROR` — 서버 쪽 상태 문제(공급자 불일치 포함).
    /// **로그아웃 사유가 아니다** — 토큰 검증은 통과했고, 재로그인해도 같은 응답이 온다
    /// (spec: feature/auth/README.md §토큰·세션).
    case serverError
    /// 동의 저장 400(버전 불일치 등) — 오류로 끝내지 않고 `GET /consents` 재조회 후 화면을 다시 그린다.
    case consentVersionMismatch
    /// 탈퇴 500 — 계정이 남아 있을 수 있어 **로그아웃하지 않고** 재시도한다.
    case accountDeletionFailed
    /// 401 — 세션 만료(탈퇴·토큰 폐기 포함). 재시도로 풀리지 않으므로 **조용히 로그아웃**한다
    /// (spec: feature/auth/README.md §토큰·세션 — 탈퇴를 콕 집어 적어둔다).
    case sessionExpired
    case unknown
}
