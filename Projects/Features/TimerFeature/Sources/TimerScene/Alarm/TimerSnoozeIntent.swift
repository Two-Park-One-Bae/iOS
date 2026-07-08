import AppIntents
import Foundation
import Domain
import Data

// AlarmKit 알람의 [+5분] 버튼(secondary, .countdown Repeat)용 App Intent.
// 시스템이 postAlert(5분) 뒤 알람을 재발하고, 이 인텐트가 타이머 endAt을 5분 뒤로
// 갱신한다(App Group UserDefaults → 앱 재시작/포그라운드 시 반영).
@available(iOS 26.0, *)
struct TimerSnoozeIntent: LiveActivityIntent {

    static var title: LocalizedStringResource = "타이머 +5분"
    static var description = IntentDescription("치료 타이머를 5분 뒤에 다시 알림합니다.")

    @Parameter(title: "Timer ID", default: "")
    var id: String

    init() {}
    init(id: String) { self.id = id }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: id) else { return .result() }
        let repo = TimerRepository()
        var timers = repo.loadTimers()
        guard let i = timers.firstIndex(where: { $0.id == uuid }) else { return .result() }
        timers[i].endAt = Date().addingTimeInterval(5 * 60)
        timers[i].state = .running
        repo.saveTimers(timers)
        return .result()
    }
}
