import Foundation
import Combine
import Domain

// iOS 26 미만 커스텀 알람 스케줄러 — 시스템 AlarmKit이 없는 버전을 위한 자체 구현.
// ① 기존 TimerAlarmScheduler(UNUserNotificationCenter 단발 알림 + 권한)를 합성하고,
// ② 강제종료 대비 반복 알림(RepeatedNotificationScheduler)을 얹는다.
// 백그라운드 무음 뚫기(.playback 루핑)는 BackgroundAudioKeepAlive + TimerRingingAlarmPresenter가 담당.
public final class CustomAlarmScheduler: TimerAlarmScheduling {

    private let base: TimerAlarmScheduler
    private let repeater: RepeatedNotificationScheduler

    public init() {
        self.base = TimerAlarmScheduler()
        self.repeater = RepeatedNotificationScheduler()
    }

    public func requestAuthorization() -> AnyPublisher<Bool, Never> {
        base.requestAuthorization()
    }

    public func authorizationStatus() -> AnyPublisher<TimerAlarmAuthorizationStatus, Never> {
        base.authorizationStatus()
    }

    public func scheduleAlarm(id: UUID, label: String, categoryName: String, body: String, fireDate: Date) {
        base.scheduleAlarm(id: id, label: label, categoryName: categoryName, body: body, fireDate: fireDate)
        repeater.scheduleRepeating(id: id, label: label, body: body, startDate: fireDate)
    }

    public func cancelAlarm(id: UUID) {
        base.cancelAlarm(id: id)
        repeater.cancelRepeating(id: id)
    }
}
