import SwiftUI
import UserNotifications

@main
struct WatchApp: App {
    @StateObject private var connectivity = WatchConnectivityManager.shared

    init() {
        // 백그라운드 실행에도 알림 액션([완료])을 잡도록 delegate·카테고리를 앱 시작 시 등록.
        UNUserNotificationCenter.current().delegate = NotificationActionHandler.shared
        WatchNotificationScheduler.registerCategory()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivity)
        }
        // 잠금화면 커스텀 알림 화면(e0iD7H 모양) — 로컬 알림 발화 시 시스템이 렌더.
        WKNotificationScene(controller: TimerNotificationController.self, category: "TIMER_EXPIRY")
    }
}
