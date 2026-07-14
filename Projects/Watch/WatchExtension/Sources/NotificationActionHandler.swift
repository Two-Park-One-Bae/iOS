import UserNotifications

// 알림 표시 정책 — 앱이 포그라운드면 배너 대신 앱의 e0iD7H(RingingCoordinator)를 쓰므로 표시 억제.
// 배너 탭은 기본 동작(앱 열기)에 맡긴다.
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
