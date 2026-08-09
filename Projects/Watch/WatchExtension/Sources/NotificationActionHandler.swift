import UserNotifications

// 알림 표시 정책 — 포그라운드에서는 배너를 띄우지 않는다.
// 만료 알람은 폰 AlarmKit(26.1+)이 워치까지 울리므로, 배너까지 겹치면 '중복 알림'이 된다.
// 배너는 백그라운드에서 "무슨 타이머인지" 알리는 용도이고, 탭은 기본 동작(앱 열기)에 맡긴다.
final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationActionHandler()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }
}
