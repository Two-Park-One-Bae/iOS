import UserNotifications
import TimerDomain

// 타이머 만료 시각(endAt)에 워치 로컬 배너 알림을 예약 — "무슨 타이머인지"(라벨)를 표시한다.
//
// 폰은 타이머 변경마다 updateApplicationContext 로 push 하고, 이는 워치 앱을 백그라운드로 깨워
// WatchConnectivityManager.apply() → reconcile 을 실행한다. 표준 배너 알림(커스텀 화면 없음)으로,
// title=타이머명, body=분류 종료. 알람(소리·지속 진동)은 폰 AlarmKit / 워치 세션이 담당.
@MainActor
enum WatchNotificationScheduler {

    // 우리가 예약해 둔 알림 식별자(=타이머 id) — running 이 아니게 되면 취소하기 위해 추적.
    private static var scheduled = Set<String>()

    nonisolated static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// 스냅샷의 running 타이머를 각자의 endAt 에 (재)예약하고, 사라진 것은 취소.
    static func reconcile(with timers: [TreatmentTimerModel]) {
        let center = UNUserNotificationCenter.current()
        // 이미 만료된 것은 트리거를 못 걸므로 제외.
        let running = timers.filter { $0.state == .running && $0.endAt.timeIntervalSinceNow > 0.5 }
        let desired = Set(running.map { $0.id.uuidString })

        let stale = scheduled.subtracting(desired)
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(stale))
        }

        for timer in running {
            let content = UNMutableNotificationContent()
            content.title = timer.label                               // "수혈 바이탈" 등 타이머명
            content.body = "\(timer.category.displayName) 타이머 종료"   // 분류 + 종료
            content.sound = .default
            content.userInfo = ["id": timer.id.uuidString]
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
