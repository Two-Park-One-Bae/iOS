//
//  PillHistoryModel.swift
//  Domain
//

import Foundation

/// 식별 기록 한 건의 요약 — 목록 · 홈 최근 식별 카드 표시용 (NM-552).
public struct PillHistorySummaryModel: Equatable {
    public let historyId: String
    /// 처음 저장한 서버 시각. 파싱에 실패하면 nil — 시각 없이 표시한다.
    public let identifiedAt: Date?
    public let firstPillName: String
    public let pillCount: Int

    public init(historyId: String, identifiedAt: Date?, firstPillName: String, pillCount: Int) {
        self.historyId = historyId
        self.identifiedAt = identifiedAt
        self.firstPillName = firstPillName
        self.pillCount = pillCount
    }

    /// 첫 품목명 뒤에 붙는 `외 N`. 알약이 하나면 nil.
    public var othersText: String? {
        pillCount > 1 ? "외 \(pillCount - 1)" : nil
    }
}

/// 식별 기록 목록 한 묶음. `nextCursor`가 nil이면 마지막 묶음이다.
public struct PillHistoryPageModel: Equatable {
    public let items: [PillHistorySummaryModel]
    public let nextCursor: String?

    public init(items: [PillHistorySummaryModel], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

/// 식별 기록 한 건 전체 — 기록 상세 화면 (NM-552).
public struct PillHistoryModel: Equatable {
    public let historyId: String
    public let identifiedAt: Date?
    /// 화면 순서 그대로. 같은 품목이 여러 번 들어갈 수 있다.
    public let pills: [PillHistoryPillModel]

    public init(historyId: String, identifiedAt: Date?, pills: [PillHistoryPillModel]) {
        self.historyId = historyId
        self.identifiedAt = identifiedAt
        self.pills = pills
    }
}

/// 기록 속 알약 하나. 품목명 · 업체명 · 허가상태는 저장 시점 값이고, 세부정보는 지금 데이터로 조회한다.
public struct PillHistoryPillModel: Equatable {
    public let pillCode: String
    public let pillName: String
    public let companyName: String
    public let licenseStatus: LicenseStatus
    public let pillThumbnailUrl: String?

    public init(pillCode: String, pillName: String, companyName: String, licenseStatus: LicenseStatus, pillThumbnailUrl: String?) {
        self.pillCode = pillCode
        self.pillName = pillName
        self.companyName = companyName
        self.licenseStatus = licenseStatus
        self.pillThumbnailUrl = pillThumbnailUrl
    }
}

// MARK: - Errors

/// 기록 한 건 조회 404 — 다른 기기에서 지웠거나 100건 상한으로 지워진 기록.
public struct PillHistoryNotFoundError: Error {
    public init() {}
}

/// 저장 400 — 같은 요청은 같은 결과라 다시 시도하지 않는다.
public struct PillHistoryRejectedError: Error {
    public init() {}
}
