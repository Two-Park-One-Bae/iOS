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
    /// 폰이 AlarmKit(iOS 26.1+)으로 알람을 처리하는지.
    /// true면 AlarmKit이 워치까지 울리므로 워치는 자체 알람(WKExtendedRuntimeSession)을 안 켠다(중복 방지).
    /// nil/false(구형 폰)면 워치가 자기 세션 알람을 켜서 확실히 울린다.
    /// (옵셔널 — 구버전 스냅샷과 하위호환)
    public let alarmKitActive: Bool?
    /// 폰(앱)의 알람 권한 승인 여부 (NM-360). false면 폰이 알람을 못 울리므로 워치는
    /// 프리셋 시작을 막고 "앱에서 알림 권한을 켜세요"를 안내한다 — 권한 없이 시작해
    /// 알람이 안 울리는 죽은 타이머 방지. nil(구형 폰·최초 동기화 전)이면 막지 않는다.
    public let alarmAuthorized: Bool?

    public init(
        snapshotAt: Date,
        timers: [TreatmentTimerModel],
        presets: [TimerPresetModel],
        alarmKitActive: Bool? = nil,
        alarmAuthorized: Bool? = nil
    ) {
        self.snapshotAt = snapshotAt
        self.timers = timers
        self.presets = presets
        self.alarmKitActive = alarmKitActive
        self.alarmAuthorized = alarmAuthorized
    }
}

// MARK: - WCSession 전송 (폰·워치 공용)

public extension TimerSyncSnapshot {
    /// applicationContext·message 딕셔너리의 페이로드 키.
    /// 폰·워치가 같은 키·같은 코딩을 써야 스냅샷이 무손실로 왕복한다.
    static let wcPayloadKey = "timerSyncSnapshot"

    /// WCSession(`updateApplicationContext`·`sendMessage`)으로 보낼 딕셔너리.
    /// 값은 인코딩된 Data 하나 — 딕셔너리 자체는 property-list 호환.
    func wcPayload() throws -> [String: Any] {
        [Self.wcPayloadKey: try JSONEncoder().encode(self)]
    }

    /// 수신 딕셔너리에서 스냅샷 복원. 키가 없거나 형식이 어긋나면 nil.
    static func decode(fromWCPayload dict: [String: Any]) -> TimerSyncSnapshot? {
        guard let data = dict[wcPayloadKey] as? Data else { return nil }
        return try? JSONDecoder().decode(TimerSyncSnapshot.self, from: data)
    }
}
