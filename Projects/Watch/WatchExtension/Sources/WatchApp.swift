import SwiftUI
import UserNotifications

@main
struct WatchApp: App {
    @StateObject private var connectivity = WatchConnectivityManager.shared

    init() {
        // 알림 탭 처리 + 포그라운드 표시 억제(그땐 e0iD7H 사용).
        UNUserNotificationCenter.current().delegate = NotificationActionHandler.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivity)
        }
    }
}
