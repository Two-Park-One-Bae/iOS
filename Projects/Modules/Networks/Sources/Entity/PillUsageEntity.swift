//
//  PillUsageEntity.swift
//  Networks
//
//  Created by 바견규 on 7/20/26.
//

import Foundation

/// 식별 사용량 (NM-322). `POST /pill-attributes` 200·429 응답과 `GET /pill-attributes/usage` 가 공유한다.
///
/// `limit`은 서버 설정값이다 — 클라이언트에 15를 하드코딩하지 않는다(spec: api/openapi.yaml Usage).
public struct PillUsageEntity: Decodable {
    public let limit: Int
    public let remaining: Int
    /// 다음 리셋 시각(KST 자정). ISO 8601 문자열 — BaseService가 기본 JSONDecoder를 쓰므로 원문으로 받는다.
    public let resetAt: String

    public init(limit: Int, remaining: Int, resetAt: String) {
        self.limit = limit
        self.remaining = remaining
        self.resetAt = resetAt
    }
}

/// `POST /api/v0/pill-attributes` 200 응답 (API 0.13.0).
///
/// 0.13.0에서 bare array → `{ items, usage }` 로 래핑되는 **breaking 변경**이 있었다.
/// 서버 배포가 앱보다 늦을 수 있어 전환 기간 동안 **두 형태를 모두 받는다** — 옛 형태로 오면 `usage`가 nil이고,
/// 그때는 잔여를 '미확인'으로 두고 진입을 막지 않는다(spec: 잔여 미확인 시 통과, 최종 판정은 429).
public struct PillAttributeResponseEntity: Decodable {
    public let items: [PillAttributeEntity]
    public let usage: PillUsageEntity?

    enum CodingKeys: String, CodingKey {
        case items, usage
    }

    public init(from decoder: Decoder) throws {
        if let legacyArray = try? decoder.singleValueContainer().decode([PillAttributeEntity].self) {
            self.items = legacyArray
            self.usage = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try container.decode([PillAttributeEntity].self, forKey: .items)
        self.usage = try container.decodeIfPresent(PillUsageEntity.self, forKey: .usage)
    }
}

/// 429 `LIMIT_EXCEEDED` 응답 — `ProblemDetail` + `usage`(remaining=0 · resetAt).
public struct PillLimitExceededEntity: Decodable {
    public let usage: PillUsageEntity
}
