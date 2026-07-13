import SwiftUI
import WatchKit
import UserNotifications
import TimerDomain

// 커스텀 알림 화면 호스트 — 로컬 알림(category "TIMER_EXPIRY") 발화 시 AlarmNotificationView 를 그린다.
// WatchApp 의 WKNotificationScene 에 등록. 잠금화면/손목 내림 상태에서도 이 뷰가 표시된다.
final class TimerNotificationController: WKUserNotificationHostingController<AlarmNotificationView> {

    private var label = "타이머 종료"
    private var category: TimerCategory = .treatment

    override var body: AlarmNotificationView {
        AlarmNotificationView(label: label, category: category)
    }

    override func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        if !content.title.isEmpty { label = content.title }
        if let raw = content.userInfo["category"] as? String,
           let parsed = TimerCategory(rawValue: raw) {
            category = parsed
        }
    }
}
