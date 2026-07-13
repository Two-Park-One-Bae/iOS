import UserNotifications
import TimerDomain

// 워치 로컬 알림을 타이머 만료 시각(endAt)에 예약 — 앱이 닫혀 있어도 워치가 "무조건" 울린다(햅틱+알림).
//
// 폰은 타이머 변경마다 updateApplicationContext 로 push 하고, 이는 워치 앱을 백그라운드로 깨워
// WatchConnectivityManager.apply() 를 실행한다. 그 안에서 reconcile 을 호출하므로
// 폰에서 시작한 타이머(워치 앱을 안 연 경우 포함)도 워치가 스스로 무장한다.
@MainActor
enum WatchNotificationScheduler {

    // 우리가 예약해 둔 알림 식별자(=타이머 id) — running 이 아니게 되면 취소하기 위해 추적.
    private static var scheduled = Set<String>()

    /// 잠금화면 커스텀 알림(TimerNotificationController)과 [완료] 액션을 등록.
    static let categoryId = "TIMER_EXPIRY"

    nonisolated static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // 알림 카테고리 등록 — [완료] 액션. 앱 시작 시 1회 호출(App.init).
    nonisolated static func registerCategory() {
        let complete = UNNotificationAction(
            identifier: "COMPLETE",
            title: "완료",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryId,
            actions: [complete],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// 스냅샷의 running 타이머를 각자의 endAt 에 (재)예약하고, 사라진 것은 취소.
    static func reconcile(with timers: [TreatmentTimerModel]) {
        let center = UNUserNotificationCenter.current()
        // 이미 만료된 것은 트리거를 못 걸므로 제외(그건 울림 화면이 처리).
        let running = timers.filter { $0.state == .running && $0.endAt.timeIntervalSinceNow > 0.5 }
        let desired = Set(running.map { $0.id.uuidString })

        let stale = scheduled.subtracting(desired)
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(stale))
        }

        for timer in running {
            let content = UNMutableNotificationContent()
            content.title = timer.label
            content.body = "\(timer.category.displayName) 타이머 종료"
            content.sound = .default   // 워치에선 설정에 따라 햅틱으로 전달됨
            // 커스텀 잠금화면 UI(TimerNotificationController) + [완료] 액션 연결.
            content.categoryIdentifier = categoryId
            content.userInfo = ["id": timer.id.uuidString, "category": timer.category.rawValue]
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, timer.endAt.timeIntervalSinceNow),
                repeats: false
            )
            // 같은 식별자로 add 하면 기존 예약을 대체(endAt 변경 시 갱신).
            let request = UNNotificationRequest(
                identifier: timer.id.uuidString,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
        scheduled = desired
    }

    /// [완료]/삭제 시 해당 타이머 알림 취소.
    static func cancel(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        scheduled.remove(id.uuidString)
    }
}
