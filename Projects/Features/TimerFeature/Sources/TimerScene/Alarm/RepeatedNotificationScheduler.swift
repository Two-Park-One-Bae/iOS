import Foundation
import UserNotifications

// 강제종료 대비 반복 알림 (커스텀 방식) — endAt 이후 1분 간격으로 재알림하여
// 사용자가 인지/확인할 때까지 끈질기게 알림. 앱당 pending 64개 한도를 고려해
// 타이머당 count개를 예약한다. 앱이 살아있을 때는 AlarmSoundPlayer 루핑이 주 신호이고,
// 이 반복 알림은 "앱이 강제종료된" 상태의 폴백 역할.
final class RepeatedNotificationScheduler {

    private let center = UNUserNotificationCenter.current()

    /// endAt 이후 1분 간격 재알림 횟수 (타이머당).
    /// 64개 pending 한도 + 다중 타이머를 고려해 15로 잡음 (~15분 폴백, 4개 동시 타이머 ≈ 60).
    private let count = 15
    private let interval: TimeInterval = 60

    func scheduleRepeating(id: UUID, label: String, body: String, startDate: Date) {
        cancelRepeating(id: id)
        for index in 1...count {
            let fireDate = startDate.addingTimeInterval(TimeInterval(index) * interval)
            let delay = fireDate.timeIntervalSinceNow
            guard delay > 0 else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(label) 종료"
            content.body = body
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            content.categoryIdentifier = TimerAlarmScheduler.Action.category

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(identifier: identifier(id: id, index: index),
                                                content: content,
                                                trigger: trigger)
            center.add(request)
        }
    }

    func cancelRepeating(id: UUID) {
        let ids = (1...count).map { identifier(id: id, index: $0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    private func identifier(id: UUID, index: Int) -> String {
        "\(id.uuidString)-repeat-\(index)"
    }
}
