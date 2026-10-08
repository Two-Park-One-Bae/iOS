//
//  AuthRequest.swift
//  Networks
//
//  Created by 바견규 on 8/28/26.
//

import Foundation

/// POST /api/v0/auth/kakao/token 요청 바디.
public struct KakaoTokenRequest: Encodable {
    public let kakaoAccessToken: String

    public init(kakaoAccessToken: String) {
        self.kakaoAccessToken = kakaoAccessToken
    }
}

/// POST /api/v0/users/me/consents 요청 바디.
///
/// **보낸 항목만** 갱신된다(openapi 0.28.0). 필수 항목은 `agreed=true` 만, 선택 항목(`OVERSEAS`)은
/// `true`·`false` 모두 받는다. 필수의 `agreed=false`·버전 불일치·모르는 `type` 은 400 이다.
public struct ConsentAgreementsRequest: Encodable {
    public let agreements: [ConsentAgreementRequest]

    public init(agreements: [ConsentAgreementRequest]) {
        self.agreements = agreements
    }
}

public struct ConsentAgreementRequest: Encodable {
    public let type: String
    /// 동의한 문서 버전. `GET /consents` 로 받은 값을 그대로 되돌려준다 — 클라이언트가 하드코딩하지 않는다.
    public let version: String
    public let agreed: Bool

    public init(type: String, version: String, agreed: Bool) {
        self.type = type
        self.version = version
        self.agreed = agreed
    }
}
