import UserNotifications
import TimerDomain

// 알림 상호작용 처리 — [완료] 액션/탭 시 폰에 remove 명령 전송, 포그라운드 표시는 억제.
// 앱 시작 시 UNUserNotificationCenter.delegate 로 등록(백그라운드 실행에도 잡히도록 App.init 에서).
final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationActionHandler()

    // 알림 탭 또는 [완료] 액션 — 해당 타이머를 폰에서 삭제.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let idString = response.notification.request.content.userInfo["id"] as? String
        Task { @MainActor in
            if let idString, let id = UUID(uuidString: idString) {
                WatchConnectivityManager.shared.send(command: .remove(id: id))
                WatchNotificationScheduler.cancel(id: id)
            }
            completionHandler()
        }
    }

    // 앱이 포그라운드면 배너 대신 앱의 전체화면 알림(RingingCoordinator)을 쓰므로 표시 억제.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }
}
