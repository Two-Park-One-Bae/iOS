import AppIntents
import Foundation
import Domain
import Data

// AlarmKit 알람의 [완료] 버튼(stop)용 App Intent.
// 시스템이 알람을 자동으로 끄고, 이 인텐트가 타이머를 App Group UserDefaults에서
// 삭제한다(앱이 꺼져 있어도 별도 프로세스에서 실행 → 앱 재시작 시 반영).
@available(iOS 26.0, *)
struct TimerStopIntent: LiveActivityIntent {

    static var title: LocalizedStringResource = "타이머 완료"
    static var description = IntentDescription("치료 타이머를 종료합니다.")

    @Parameter(title: "Timer ID", default: "")
    var id: String

    init() {}
    init(id: String) { self.id = id }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: id) else { return .result() }
        let repo = TimerRepository()
        var timers = repo.loadTimers()
        // 앱 밖 AlarmKit [완료] → timer_complete 지연 기록. 백그라운드 인텐트라 Firebase
        // 초기화가 불확실해 직접 발사하지 않고, 앱이 다음 활성화 때 drain 해 발사한다.
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
