//
//  TimerSyncSnapshot.swift
//  TimerDomain — 폰↔워치 동기화 계약 (NM-269)
//
//  spec/feature/care-timer/domain-model.md "폰↔워치 동기화 계약":
//  - 페이로드 = snapshotAt(생성 시각) + Timer 목록 + Preset 목록 (별도 스키마 없음)
//  - 변경마다 전체 목록 전송, 어긋나면 snapshotAt 최신인 쪽이 이김
//  - 삭제 전파: 스냅샷에 없는 항목 = 삭제 (tombstone 없음)

import Foundation

public struct TimerSyncSnapshot: Codable, Equatable, Sendable {
    /// 스냅샷 생성 시각 — 충돌 시 최신이 이김
    public let snapshotAt: Date
    public let timers: [TreatmentTimerModel]
    public let presets: [TimerPresetModel]

    public init(snapshotAt: Date, timers: [TreatmentTimerModel], presets: [TimerPresetModel]) {
        self.snapshotAt = snapshotAt
        self.timers = timers
        self.presets = presets
    }
}
