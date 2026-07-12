import Foundation
import AppIntents
#if canImport(AlarmKit)
import AlarmKit
import SwiftUI
import TimerShared
#endif

// 위젯에서 시작한 타이머의 [완료](stop) — App Group 에서 타이머를 삭제한다.
// 앱의 TimerStopIntent 과 동일 효과(App Group 저장소에서 제거), 별도 프로세스에서 실행.
@available(iOS 26.0, *)
struct TimerWidgetStopIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "타이머 완료"

    @Parameter(title: "Timer ID", default: "")
    var id: String

    init() {}
    init(id: String) { self.id = id }

    func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: id) { TimerPresetStore.removeTimer(id: uuid) }
        return .result()
    }
}

#if canImport(AlarmKit)

// 위젯 프로세스 AlarmKit 예약 (iOS 26.1+). 앱 AlarmKitAlarmScheduler 와 동일 표현.
@available(iOS 26.1, *)
enum TimerWidgetAlarmScheduler {
    static func schedule(id: UUID, label: String, categoryName: String, seconds: Int) async throws {
        let alert = AlarmPresentation.Alert(
            title: "\(label) 종료",
            stopButton: AlarmButton(text: "완료", textColor: .white, systemImageName: "checkmark")
        )
        let presentation = AlarmPresentation(
            alert: alert,
            countdown: AlarmPresentation.Countdown(
                title: "치료 타이머",
                pauseButton: AlarmButton(text: "일시정지", textColor: .white, systemImageName: "pause.fill")
            ),
            paused: AlarmPresentation.Paused(
                title: "일시정지됨",
                resumeButton: AlarmButton(text: "재개", textColor: .white, systemImageName: "play.fill")
            )
        )
        let attributes = AlarmAttributes<CareTimerAlarmMetadata>(
            presentation: presentation,
            metadata: CareTimerAlarmMetadata(label: label, categoryName: categoryName, duration: seconds),
            tintColor: Color(red: 0.961, green: 0.620, blue: 0.043)
        )
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: Alarm.CountdownDuration(preAlert: TimeInterval(seconds), postAlert: nil),
            schedule: nil,
            attributes: attributes,
            stopIntent: TimerWidgetStopIntent(id: id.uuidString),
            sound: .default
        )
        try await AlarmManager.shared.schedule(id: id, configuration: configuration)
    }
}

#endif
