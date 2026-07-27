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

    // 식별 한도(NM-322)는 기기별로 센다. 카운트 키인 X-Device-Id를 한도 대상 엔드포인트에 붙인다.
    // 후보·세부정보 조회는 Gemini를 쓰지 않아 카운트 대상이 아니므로 붙이지 않는다.
    // TODO: App Check 도입 시 X-Firebase-AppCheck 추가 — 토큰 발급이 async라 RequestInterceptor로 붙여야 한다.
    public var headers: [String: String]? {
        var headers = ["Content-Type": "application/json"]

        switch self {
        case .pillAttributes, .pillAttributesUsage:
            // Keychain 불가 시 nil — 식별 진입에서 이미 막으므로(fail-closed) 여기선 헤더만 생략.
            if let deviceId = DeviceIdentifier.current { headers["X-Device-Id"] = deviceId }
        case .pillCandidates, .pillDetails, .pillImagesUploadUrl:
            // upload-url은 App Check(인터셉터)만 필요 — usage와 무관해 X-Device-Id를 붙이지 않는다 (NM-348).
            break
        }

        return headers
    }
}
