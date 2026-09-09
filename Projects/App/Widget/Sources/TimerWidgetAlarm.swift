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
        // 분류 태그 + 처치명을 헤드라인으로: "[처치] 수혈 바이탈".
        // 완료 버튼 텍스트·체크마크를 빨강(#EF4444)으로 — 전체화면 알람에서 색 넣을 수 있는 텍스트.
        let alert = AlarmPresentation.Alert(
            title: "❗ [\(categoryName)] \(label)",
            stopButton: AlarmButton(
                text: "완료",
                textColor: Color(red: 0.937, green: 0.267, blue: 0.267),
                systemImageName: "checkmark"
            )
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
            tintColor: Color(red: 0.937, green: 0.267, blue: 0.267)   // 빨강 #EF4444 (경고·알람)
        )
        // 울림 방식은 앱과 **같은 값**을 봐야 한다 (NM-447).
        // RingModeStore 는 앱 그룹 UserDefaults 라 위젯 프로세스에서도 그대로 읽힌다 —
        // 예전엔 .default 로 못박혀 있어서, 앱에서 시작하면 무음인데 위젯에서 시작하면
        // 소리가 났다. 야간 병동에서 무음으로 맞춰둔 사용자에게 예고 없이 소리가 나간다.
        //
        // 규칙은 AlarmKitAlarmScheduler 와 동일: 소리=기본 알람음+진동 /
        // 무음=무음 사운드 파일(소리 없음, 시스템 진동은 남음 — AlarmKit 알람은 발화 시 항상 진동).
        let useSound = RingModeStore.shared.current == .sound
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: Alarm.CountdownDuration(preAlert: TimeInterval(seconds), postAlert: nil),
            schedule: nil,
            attributes: attributes,
            stopIntent: TimerWidgetStopIntent(id: id.uuidString),
            sound: useSound ? .default : .named("silence.caf")
        )
        try await AlarmManager.shared.schedule(id: id, configuration: configuration)
    }
}

#endif
