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
    // GET /api/v0/pill-attributes/usage — 잔여 식별 횟수 조회 (NM-331). 조회 전용 · 카운트 미증가
    case pillAttributesUsage
    // POST /api/v0/pill-images/upload-url — 원본 이미지 S3 업로드용 presigned URL 발급 (NM-348).
    // 본문 없음 · App Check만 · usage 무관. 식별과 분리된 베스트 에포트.
    case pillImagesUploadUrl
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
        case .pillImagesUploadUrl: return "/pill-images/upload-url"
        }
    }

    public var method: Moya.Method {
        switch self {
        case .pillAttributes, .pillCandidates, .pillImagesUploadUrl: return .post
        case .pillDetails, .pillAttributesUsage:                     return .get
        }
    }

    public var task: Moya.Task {
        switch self {
        case .pillAttributes(let request):
            return .requestJSONEncodable(request)
        case .pillCandidates(let request):
            return .requestJSONEncodable(request)
        case .pillDetails, .pillAttributesUsage, .pillImagesUploadUrl:
            return .requestPlain
        }
    }

    // X-Device-Id 는 폐기됐다 (NM-410 클린 컷오버). 식별 한도 카운트 키가 기기 UUID 에서
    // 안정 소셜 식별자 해시로 바뀌었고, 신원은 Bearer(Firebase ID 토큰)로만 판정한다
    // (spec: domains/auth.md §클린 컷오버). Authorization·X-Firebase-AppCheck 는
    // 둘 다 발급이 async 라 APIRequestInterceptor 가 붙이므로 여기서는 BaseAPI 기본 헤더를 그대로 쓴다.
}
