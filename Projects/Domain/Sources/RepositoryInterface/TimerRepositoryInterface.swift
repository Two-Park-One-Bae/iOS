//
//  TimerRepositoryInterface.swift
//  Domain
//
//  Created by 바견규 on 7/7/26.
//

import Combine
import Foundation

// 타이머·프리셋 영속화. 구현체는 App Group UserDefaults 기반 —
// 추후 워치/위젯 타깃이 같은 저장소를 읽는다.
public protocol TimerRepositoryProtocol {
    func loadTimers() -> [TreatmentTimerModel]
    func saveTimers(_ timers: [TreatmentTimerModel])
    func loadPresets() -> [TimerPresetModel]
    func savePresets(_ presets: [TimerPresetModel])
}

// 폰→워치 동기화 추상화. 구현체(WCSession)는 App 타깃에 둔다 — Domain은 전송 수단을 모른다.
// 계약(NM-269): 변경마다 전체 목록 스냅샷 전송, 최신 snapshotAt 이 이김.
public protocol TimerWatchSyncing {
    func sync(timers: [TreatmentTimerModel], presets: [TimerPresetModel])
}

// 로컬 알람(UNUserNotificationCenter) 스케줄링 추상화
public protocol TimerAlarmScheduling {
    func requestAuthorization() -> AnyPublisher<Bool, Never>
    func authorizationStatus() -> AnyPublisher<TimerAlarmAuthorizationStatus, Never>
    /// - parameter body: 잠금화면/배너 본문 (예: "15분 타이머가 끝났어요") —
    ///   디자인 '시스템 알람' 화면(spec/design wrEli·ZFXjS) 정합.
    func scheduleAlarm(id: UUID, label: String, categoryName: String, body: String, fireDate: Date)
    func cancelAlarm(id: UUID)
}

public enum TimerAlarmAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}
