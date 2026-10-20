import AppIntents
import Foundation
import Domain
import Data

// 위젯에서 시작한 타이머 알람의 [완료](stop) — **앱 프로세스 쪽 구현**.
//
// LiveActivityIntent 는 버튼이 어디(위젯 · 잠금화면 알람)에 있든 앱 프로세스에서 실행된다.
// 위젯이 예약한 알람은 stopIntent 로 TimerWidgetStopIntent 를 싣는데, 이 타입이 위젯 타깃에만
// 있으면 시스템이 앱에서 찾지 못해("Could not find an intent with identifier TimerWidgetStopIntent")
// 알람만 꺼지고 타이머는 저장소에 남았다 — 앱을 열면 끈 타이머가 만료 카드로 다시 뜨고,
// timer_complete · 스토어 리뷰 요청(NM-560)도 빠졌다.
//
// 그래서 같은 식별자(타입 이름)의 인텐트를 앱에도 둔다. 하는 일은 앱의 TimerStopIntent 와 같다 —
// App Group 저장소에서 지우고, 완료를 지연 분석 큐에 쌓는다(앱이 다음 활성화 때 drain).
// 위젯 쪽 정의(Widget/Sources/TimerWidgetAlarm.swift)와 이름 · 매개변수를 맞춰야 한다.
@available(iOS 26.0, *)
struct TimerWidgetStopIntent: LiveActivityIntent {

    static var title: LocalizedStringResource = "타이머 완료"

    @Parameter(title: "Timer ID", default: "")
    var id: String

    init() {}
    init(id: String) { self.id = id }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: id) else { return .result() }
        let repo = TimerRepository()
        var timers = repo.loadTimers()
        if let t = timers.first(where: { $0.id == uuid }) {
            WidgetAnalyticsQueue.appendTimerComplete(
                PendingWidgetTimerComplete(
                    category: t.category.displayName, durationSec: t.duration, completedAt: Date()))
        }
        timers.removeAll { $0.id == uuid }
        repo.saveTimers(timers)
        return .result()
    }
}
