//
//  TimerEntity.swift
//  TimerDomain — 폰(iOS)·워치(watchOS) 공용
//
//  spec/feature/care-timer/domain-model.md (NM-258) —
//  두 플랫폼이 동일하게 구현하는 데이터 계약. 상태는 RUNNING/PAUSED/RINGING 3개뿐,
//  완료·취소는 상태가 아니라 즉시 삭제. 시간은 endAt 하나로 관리(남은 시간 = endAt − now).

import Foundation

// MARK: - 분류 (투약 / 처치 / 검사)

public enum TimerCategory: String, Codable, Equatable, Sendable, CaseIterable {
    case medication   // 투약
    case treatment    // 처치
    case examination  // 검사

    /// 표시명 (위젯·Live Activity·알람·워치 공용) — 프라이버시상 노출 가능한 분류 태그.
    public var displayName: String {
        switch self {
        case .medication:  return "투약"
        case .treatment:   return "처치"
        case .examination: return "검사"
        }
    }
}

// MARK: - 처치 타이머

public enum TreatmentTimerState: String, Codable, Equatable, Sendable {
    case running  // 실행 중
    case paused   // 일시정지 — 만료 발생 없음
    case ringing  // 울림 — endAt 도달, [완료]/[+5분] 전까지 유지
}

public struct TreatmentTimerModel: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let label: String            // 처치 키워드 — 프리셋에서 복사
    public let category: TimerCategory  // 프리셋에서 복사
    public var memo: String?            // 시작 후 입력
    public var duration: Int            // 전체 초 — 진행률 링 계산용
    public var endAt: Date              // 만료 예정 시각 — 남은 시간의 유일한 기준
    public var remaining: Int?          // 일시정지 중일 때만: 멈춘 시점의 남은 초
    public var state: TreatmentTimerState

    public init(
        id: UUID = UUID(),
        label: String,
        category: TimerCategory,
        memo: String? = nil,
        duration: Int,
        endAt: Date,
        remaining: Int? = nil,
        state: TreatmentTimerState = .running
    ) {
        self.id = id
        self.label = label
        self.category = category
        self.memo = memo
        self.duration = duration
        self.endAt = endAt
        self.remaining = remaining
        self.state = state
    }

    /// 남은 초 — PAUSED는 remaining 고정값, 그 외 endAt − now (음수 없음)
    public func remainingSeconds(at now: Date = Date()) -> Int {
        if state == .paused { return max(0, remaining ?? 0) }
        return max(0, Int(endAt.timeIntervalSince(now).rounded()))
    }
}

// MARK: - 프리셋 (템플릿 — 실행 시 타이머로 복사)

public struct TimerPresetModel: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var label: String
    public var category: TimerCategory
    public var duration: Int      // 기본 초
    public let isDefault: Bool    // 기본 6종 여부

    public init(
        id: UUID = UUID(),
        label: String,
        category: TimerCategory,
        duration: Int,
        isDefault: Bool = false
    ) {
        self.id = id
        self.label = label
        self.category = category
        self.duration = duration
        self.isDefault = isDefault
    }
}
