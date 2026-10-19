//
//  PillHistoryEntity.swift
//  Networks
//

import Foundation

/// `GET /api/v0/pill-histories` 200 응답 — 식별 기록 요약 목록 (NM-552).
public struct PillHistoryPageEntity: Decodable {
    public let items: [PillHistorySummaryEntity]
    /// 다음 묶음이 없으면 null.
    public let nextCursor: String?
}

/// 목록 · 홈 카드 표시용 요약. 알약과 사진은 한 건 조회로 받는다.
public struct PillHistorySummaryEntity: Decodable {
    public let historyId: String
    /// 처음 저장한 서버 시각. ISO 8601 문자열 — BaseService가 기본 JSONDecoder를 쓰므로 원문으로 받는다.
    public let identifiedAt: String
    public let firstPillName: String
    public let pillCount: Int
}

/// `GET /api/v0/pill-histories/{historyId}` 200 응답 — 기록 한 건 전체.
public struct PillHistoryEntity: Decodable {
    public let historyId: String
    public let identifiedAt: String
    public let pills: [PillHistoryPillEntity]
}

/// 기록 속 알약 하나. 품목명 · 업체명 · 허가상태는 저장 시점 값이다.
public struct PillHistoryPillEntity: Decodable {
    public let pillCode: String
    public let pillName: String
    public let companyName: String
    /// NORMAL · REVOKED
    public let licenseStatus: String
    /// 품목 낱알 썸네일. 기록에는 사진을 남기지 않으므로 이것이 화면의 알약 사진이다.
    public let pillThumbnailUrl: String?
}
