//
//  AuthAPI.swift
//  Networks
//
//  Created by 바견규 on 8/28/26.
//

import Foundation
import Moya

/// 회원·인증·동의 (NM-410 · spec: domains/auth.md).
///
/// 공개 엔드포인트는 `kakaoToken` · `consents` 둘뿐이다 — 나머지는 Bearer 필수.
/// 실제 헤더 부착·공개 판정은 `APIRequestInterceptor` 가 경로로 처리하므로 여기서는 신경 쓰지 않는다.
public enum AuthAPI {
    // POST /api/v0/auth/kakao/token — 카카오 액세스 토큰 → Firebase Custom Token 교환 (공개)
    case kakaoToken(request: KakaoTokenRequest)
    // GET /api/v0/consents — 필수 동의 항목·현재 버전·문서 URL (공개, 로그인 전 표시)
    case consents
    // GET /api/v0/users/me — 회원 정보 + 동의 상태. 최초 인증이면 서버가 회원을 생성(upsert)한다.
    case me
    // POST /api/v0/users/me/consents — 필수 항목 전체를 한 번에 저장. 응답은 갱신된 User.
    case saveConsents(request: ConsentAgreementsRequest)
    // DELETE /api/v0/users/me — 회원 탈퇴(계정 삭제). 204, 멱등.
    case deleteMe
}

extension AuthAPI: BaseAPI {
    public static var apiType: APIType = .auth  // baseURL = NetworkConfig.baseURL + "/api/v0"

    public var path: String {
        switch self {
        case .kakaoToken:   return "/auth/kakao/token"
        case .consents:     return "/consents"
        case .me:           return "/users/me"
        case .saveConsents: return "/users/me/consents"
        case .deleteMe:     return "/users/me"
        }
    }

    public var method: Moya.Method {
        switch self {
        case .kakaoToken, .saveConsents: return .post
        case .consents, .me:             return .get
        case .deleteMe:                  return .delete
        }
    }

    public var task: Moya.Task {
        switch self {
        case .kakaoToken(let request):   return .requestJSONEncodable(request)
        case .saveConsents(let request): return .requestJSONEncodable(request)
        case .consents, .me, .deleteMe:  return .requestPlain
        }
    }
}
