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
    /// 알람 권한 승인 여부를 App Group 에 캐시 (NM-360) — 위젯이 원탭 시작 버튼 라우팅에 읽는다.
    /// 앱만 쓰고, 위젯은 읽기 전용(위젯 프로세스는 실시작 직전 AlarmManager 로 최종 확인).
    func setAlarmAuthorized(_ authorized: Bool)
    /// 캐시된 알람 권한 승인 여부. 한 번도 기록된 적 없으면 nil (아직 물어보지 않음) — NM-360.
    func alarmAuthorizedFlag() -> Bool?
}

// 폰→워치 동기화 추상화. 구현체(WCSession)는 App 타깃에 둔다 — Domain은 전송 수단을 모른다.
// 계약(NM-269): 변경마다 전체 목록 스냅샷 전송, 최신 snapshotAt 이 이김.
public protocol TimerWatchSyncing {
    /// - parameter alarmAuthorized: 폰의 알람 권한 승인 여부(NM-360). 워치가 시작 게이트에 쓴다. nil=미상.
    func sync(timers: [TreatmentTimerModel], presets: [TimerPresetModel], alarmAuthorized: Bool?)
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
