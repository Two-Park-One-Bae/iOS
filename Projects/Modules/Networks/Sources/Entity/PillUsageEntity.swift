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

/// `POST /api/v1/pill-attributes` 200 응답 — 처음부터 `{ items, usage }` 형태다(v0 의 옛 배열 형태는 받지 않는다).
/// `usage` 는 이번 요청 차감이 반영된 잔여.
public struct PillAttributeResponseEntity: Decodable {
    public let items: [PillAttributeEntity]
    public let usage: PillUsageEntity
}

/// 429 `LIMIT_EXCEEDED` 응답 — `ProblemDetail` + `usage`(remaining=0 · resetAt).
public struct PillLimitExceededEntity: Decodable {
    public let usage: PillUsageEntity
}
