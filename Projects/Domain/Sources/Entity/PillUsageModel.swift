//
//  PillUsageModel.swift
//  Domain
//
//  Created by 바견규 on 7/20/26.
//

import Foundation

/// 식별 사용량 — 카운트·리셋·판정은 서버가 소유하고, 앱은 이 값을 표시·게이트에만 쓴다 (NM-322).
public struct PillUsageModel: Equatable {
    /// 일일 한도. **서버 설정값** — 클라이언트에 15를 하드코딩하지 않는다.
    public let limit: Int
    /// 오늘 남은 횟수.
    public let remaining: Int
    /// 다음 리셋 시각(KST 자정). 파싱 실패 시 nil — 표시 문구만 일반화되고 게이트에는 영향 없다.
    public let resetAt: Date?

    public init(limit: Int, remaining: Int, resetAt: Date?) {
        self.limit = limit
        self.remaining = remaining
        self.resetAt = resetAt
    }

    public var isExhausted: Bool { remaining <= 0 }

    /// 홈 카드·미리보기에 쓰는 표시 문구. `limit`은 서버 값이라 하드코딩하지 않는다.
    public var remainingText: String {
        "오늘 남은 횟수 \(remaining)/\(limit)"
    }
}

/// 한도 안내 팝업 문구 — 홈 진입 게이트와 429 양쪽에서 같은 문구를 써야 해서 한 곳에 둔다.
public enum PillLimitAlertText {
    public static let title = "오늘 식별 횟수를 모두 사용했어요"

    /// `resetAt`을 못 받았거나 파싱에 실패하면 시각 없이 일반화된 문구로 떨어진다.
    public static func message(resetAt: Date?) -> String {
        guard let resetAt else { return "내일 다시 이용할 수 있어요" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH:mm"

        return "내일 \(formatter.string(from: resetAt))에 초기화돼요"
    }
}

/// 속성분류 결과 + 이번 요청이 반영된 사용량 (API 0.13.0 `{ items, usage }`).
///
/// `usage`는 옵셔널이다 — 0.13.0 미적용 서버는 bare array를 주고, 그때는 잔여를 '미확인'으로 둔다.
public struct PillAttributeResultModel {
    public let items: [PillAttributeModel]
    public let usage: PillUsageModel?

    public init(items: [PillAttributeModel], usage: PillUsageModel?) {
        self.items = items
        self.usage = usage
    }
}

/// 식별 한도 도달 (429 `LIMIT_EXCEEDED`) — 미차감.
///
/// 다른 네트워크 오류와 달리 UI가 '한도 안내 팝업'으로 분기해야 해서 별도 타입으로 올린다.
/// `usage`는 429 응답에 실려 오지만, 확장 필드 파싱에 실패하면 nil일 수 있다.
public struct PillLimitExceededError: Error {
    public let usage: PillUsageModel?

    public init(usage: PillUsageModel?) {
        self.usage = usage
    }
}
