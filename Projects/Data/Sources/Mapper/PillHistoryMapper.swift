//
//  PillHistoryMapper.swift
//  Data
//

import Foundation

import Domain
import Networks

extension PillHistoryPageEntity {
    public func toDomain() -> PillHistoryPageModel {
        PillHistoryPageModel(items: items.map { $0.toDomain() }, nextCursor: nextCursor)
    }
}

extension PillHistorySummaryEntity {
    public func toDomain() -> PillHistorySummaryModel {
        PillHistorySummaryModel(
            historyId:     historyId,
            identifiedAt:  Self.parseDate(identifiedAt),
            firstPillName: firstPillName,
            pillCount:     pillCount
        )
    }

    // 서버 시각은 소수점 초가 붙을 때도 있다 — ISO8601DateFormatter는 옵션이 어긋나면 nil이라 둘 다 시도한다.
    private static let plainFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func parseDate(_ value: String) -> Date? {
        plainFormatter.date(from: value) ?? fractionalFormatter.date(from: value)
    }
}

extension PillHistoryEntity {
    public func toDomain() -> PillHistoryModel {
        PillHistoryModel(
            historyId:    historyId,
            identifiedAt: PillHistorySummaryEntity.parseDate(identifiedAt),
            pills:        pills.map { $0.toDomain() }
        )
    }
}

extension PillHistoryPillEntity {
    public func toDomain() -> PillHistoryPillModel {
        PillHistoryPillModel(
            pillCode:         pillCode,
            pillName:         pillName,
            companyName:      companyName,
            licenseStatus:    licenseStatus.uppercased() == "REVOKED" ? .revoked : .normal,
            pillThumbnailUrl: pillThumbnailUrl
        )
    }
}
