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
    ///
    /// 선택 항목(`OVERSEAS`)도 여기 걸리지만 판정을 흐리지 않는다 — 선택 항목이 옛 버전이라도
    /// `onboardingRequired` 가 오르지 않아 동의 화면 자체가 뜨지 않고, 고지사항이 바뀌어 버전이
    /// 오르면 방침도 함께 개정되므로(spec: domains/auth.md §선택 동의) 필수 쪽이 먼저 걸린다.
    var needsReconsent: Bool {
        consents.contains { $0.agreed && !$0.satisfied }
    }

    /// 그 항목의 **현재 버전**에 동의해 둔 상태인가(`agreed && satisfied`).
    ///
    /// 옛 버전에 동의한 상태는 다시 동의하기 전까지 미동의로 다룬다 (spec: domains/auth.md §선택 동의).
    func hasAgreed(to type: ConsentType) -> Bool {
        consents.contains { $0.type == type && $0.agreed && $0.satisfied }
    }

    /// 이 버전에 이미 응답했는가 — 동의든 거부든.
    ///
    /// 선택 항목을 동의 화면에 다시 보일지 가르는 값이다. 거부도 현재 버전으로 기록되므로
    /// (`ConsentStatus.version`), 거부한 사람에게 같은 버전을 다시 묻지 않는다.
    func hasResponded(to definition: ConsentDefinition) -> Bool {
        consents.contains { $0.type == definition.type && $0.version == definition.version }
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
    case terms    = "TERMS"
    case privacy  = "PRIVACY"
    /// 개인정보 국외 이전 및 제3자 제공 — **선택** (NM-548). 광고 유입 측정(에어브릿지)이 이 동의에 기댄다.
    /// 필수 여부는 서버의 `ConsentDefinition.required` 가 정한다.
    case overseas = "OVERSEAS"
}

/// 회원별 동의 상태 (`User.consents`).
public struct ConsentStatus: Equatable {
    public let type: ConsentType
    public let agreed: Bool
    /// 응답한(동의·거부) 문서 버전. 한 번도 묻지 않았으면 nil.
    /// 선택 항목은 거부도 현재 버전으로 남는다 — nil 과 거부를 이 값으로 가른다.
    public let version: String?
    /// 현재 버전 충족 여부(동의 & 최신 버전).
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
    /// 동의 정의에 이 앱이 모르는 **필수** 항목이 있다 — 저장할 수 없으므로 앱 업데이트를 안내한다 (NM-548).
    case updateRequired
    /// 탈퇴 500 — 계정이 남아 있을 수 있어 **로그아웃하지 않고** 재시도한다.
    case accountDeletionFailed
    /// 401 — 세션 만료(탈퇴·토큰 폐기 포함). 재시도로 풀리지 않으므로 **조용히 로그아웃**한다
    /// (spec: feature/auth/README.md §토큰·세션 — 탈퇴를 콕 집어 적어둔다).
    case sessionExpired
    case unknown
}
