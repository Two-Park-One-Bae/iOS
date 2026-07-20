//
//  PillAPI.swift
//  Networks
//
//  Created by 바견규 on 7/2/26.
//

import Core
import Foundation
import Moya

public enum PillAPI {
    // POST /api/v0/pill-attributes — 크롭 이미지 → 색·모양·제형 추출
    case pillAttributes(request: PillAttributeRequest)
    // POST /api/v0/pill-candidates — 수정 속성 → 후보 알약 조회
    case pillCandidates(request: PillCandidateRequest)
    // GET /api/v0/pill-details/{pillCode} — pillCode → 알약 세부정보 조회 (NM-312)
    case pillDetails(pillCode: String)
    // GET /api/v0/pill-attributes/usage — 잔여 식별 횟수 조회 (NM-331). 조회 전용 · 카운트 미증가
    case pillAttributesUsage
}

extension PillAPI: BaseAPI {
    public static var apiType: APIType = .pill  // baseURL = NetworkConfig.baseURL + "/api/v0"

    public var path: String {
        switch self {
        case .pillAttributes:  return "/pill-attributes"
        case .pillCandidates:  return "/pill-candidates"
        case .pillDetails(let pillCode):
            let encoded = pillCode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? pillCode
            return "/pill-details/\(encoded)"
        case .pillAttributesUsage: return "/pill-attributes/usage"
        }
    }

    public var method: Moya.Method {
        switch self {
        case .pillAttributes, .pillCandidates:      return .post
        case .pillDetails, .pillAttributesUsage:    return .get
        }
    }

    public var task: Moya.Task {
        switch self {
        case .pillAttributes(let request):
            return .requestJSONEncodable(request)
        case .pillCandidates(let request):
            return .requestJSONEncodable(request)
        case .pillDetails, .pillAttributesUsage:
            return .requestPlain
        }
    }

    // 식별 한도(NM-322)는 기기별로 센다. 카운트 키인 X-Device-Id를 한도 대상 엔드포인트에 붙인다.
    // 후보·세부정보 조회는 Gemini를 쓰지 않아 카운트 대상이 아니므로 붙이지 않는다.
    // TODO: App Check 도입 시 X-Firebase-AppCheck 추가 — 토큰 발급이 async라 RequestInterceptor로 붙여야 한다.
    public var headers: [String: String]? {
        var headers = ["Content-Type": "application/json"]

        switch self {
        case .pillAttributes, .pillAttributesUsage:
            headers["X-Device-Id"] = DeviceIdentifier.current
        case .pillCandidates, .pillDetails:
            break
        }

        return headers
    }
}
