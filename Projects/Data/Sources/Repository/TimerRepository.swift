//
//  TimerRepository.swift
//  Data
//
//  Created by 바견규 on 7/7/26.
//
//  App Group UserDefaults 기반 — 워치/위젯 타깃 추가 시 같은 suite를 읽는다.
//  워치 동기화(NM-258): snapshotAt 최신 스냅샷이 전체를 덮어쓴다.

import Foundation
import Domain
#if canImport(WidgetKit)
import WidgetKit
#endif

public final class TimerRepository: TimerRepositoryProtocol {

    // App Group — AlarmKit App Intent(크로스프로세스)·위젯이 같은 UserDefaults를 공유.
    public static let appGroupSuiteName: String? = "group.app.nursemate.timer"

    private enum Keys {
        static let timers = "care.timer.timers"
        static let presets = "care.timer.presets"
        static let snapshotAt = "care.timer.snapshotAt"
        static let presetsSeeded = "care.timer.presets.seeded"
        static let alarmAuthorized = "care.timer.alarmAuthorized"  // NM-360 위젯 시작 게이트
    }

    private let store: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(suiteName: String? = TimerRepository.appGroupSuiteName) {
        if let suiteName, let suite = UserDefaults(suiteName: suiteName) {
            store = suite
        } else {
            store = .standard
        }
    }

    public func loadTimers() -> [TreatmentTimerModel] {
        load([TreatmentTimerModel].self, forKey: Keys.timers) ?? []
    }

    public func saveTimers(_ timers: [TreatmentTimerModel]) {
        save(timers, forKey: Keys.timers)
        touchSnapshot()
    }

    public func loadPresets() -> [TimerPresetModel] {
        if let saved = load([TimerPresetModel].self, forKey: Keys.presets) {
            return saved
        }
        // 첫 실행 시 기본 6종 시드 — 이후 수정·삭제 유지, 자동 복원 없음
        guard !store.bool(forKey: Keys.presetsSeeded) else { return [] }
        store.set(true, forKey: Keys.presetsSeeded)
        save(Self.defaultPresets, forKey: Keys.presets)
        return Self.defaultPresets
    }

    public func savePresets(_ presets: [TimerPresetModel]) {
        save(presets, forKey: Keys.presets)
        touchSnapshot()
    }

    public func setAlarmAuthorized(_ authorized: Bool) {
        // 값이 바뀔 때만 위젯을 다시 그린다 (NM-371).
        // 설정형 위젯은 timeline policy 가 .never 라, 이 신호가 없으면 렌더 당시의 라우팅
        // (무음 시작 ↔ 앱 열기)에 그대로 굳어 권한을 나중에 허용해도 반영되지 않는다.
        let previous = store.object(forKey: Keys.alarmAuthorized) as? Bool
        store.set(authorized, forKey: Keys.alarmAuthorized)
        guard previous != authorized else { return }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    public func alarmAuthorizedFlag() -> Bool? {
        // object(forKey:) 로 "미기록(nil)"과 "false"를 구분 — 워치가 미상(nil)일 땐 차단하지 않는다.
        store.object(forKey: Keys.alarmAuthorized) as? Bool
    }

    // 기본 프리셋 6종 (spec/feature/care-timer/README.md)
    private static let defaultPresets: [TimerPresetModel] = [
        TimerPresetModel(label: "AST", category: .examination, duration: 15 * 60, isDefault: true),
        TimerPresetModel(label: "수혈 바이탈", category: .treatment, duration: 15 * 60, isDefault: true),
        TimerPresetModel(label: "투약 반응 관찰", category: .medication, duration: 30 * 60, isDefault: true),
        TimerPresetModel(label: "해열 재검", category: .examination, duration: 30 * 60, isDefault: true),
        TimerPresetModel(label: "바이탈 재측정", category: .examination, duration: 15 * 60, isDefault: true),
        TimerPresetModel(label: "체위 변경", category: .treatment, duration: 2 * 60 * 60, isDefault: true)
    ]

    // MARK: - Private

    private func touchSnapshot() {
        store.set(Date().timeIntervalSince1970, forKey: Keys.snapshotAt)
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        store.set(data, forKey: key)
    }
}
