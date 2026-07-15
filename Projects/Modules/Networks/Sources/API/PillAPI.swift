//
//  PillAPI.swift
//  Networks
//
//  Created by 바견규 on 7/2/26.
//

import Foundation
import Moya

public enum PillAPI {
    // POST /api/v0/pill-attributes — 크롭 이미지 → 색·모양·제형 추출
    case pillAttributes(request: PillAttributeRequest)
    // POST /api/v0/pill-candidates — 수정 속성 → 후보 알약 조회
    case pillCandidates(request: PillCandidateRequest)
    // GET /api/v0/pill-details/{pillCode} — pillCode → 알약 세부정보 조회 (NM-312)
    case pillDetails(pillCode: String)
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
        }
    }

    public var method: Moya.Method {
        switch self {
        case .pillAttributes, .pillCandidates: return .post
        case .pillDetails:                     return .get
        }
    }

    public var task: Moya.Task {
        switch self {
        case .pillAttributes(let request):
            return .requestJSONEncodable(request)
        case .pillCandidates(let request):
            return .requestJSONEncodable(request)
        case .pillDetails:
            return .requestPlain
        }
    }
}
