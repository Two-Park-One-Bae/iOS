import Foundation
import Combine
import AlarmKit
import SwiftUI
import Core
import Domain
import TimerShared

// iOS 26 AlarmKit 알람 스케줄러 — Clock 앱 동급 시스템 알람.
// 강제종료/잠금/무음/Focus 모두 뚫고 풀스크린+루핑으로 울림(AlarmManager가 시스템 수준 관리).
// [완료](stop)는 시스템 자동 처리 + TimerStopIntent가 모델 삭제.
// (AlarmPresentation.Alert 의 비권장 init이 iOS 26.1+ 이므로 26.1 게이트)
@available(iOS 26.1, *)
public final class AlarmKitAlarmScheduler: TimerAlarmScheduling {

    public init() {}

    public func requestAuthorization() -> AnyPublisher<Bool, Never> {
        Future { promise in
            Task {
                do {
                    let state = try await AlarmManager.shared.requestAuthorization()
                    promise(.success(state == .authorized))
                } catch {
                    promise(.success(false))
                }
            }
        }.eraseToAnyPublisher()
    }

    public func authorizationStatus() -> AnyPublisher<TimerAlarmAuthorizationStatus, Never> {
        // authorizationState 는 동기·nonisolated get 프로퍼티 — async 작업이 없으므로 Just.
        Just(Self.map(AlarmManager.shared.authorizationState)).eraseToAnyPublisher()
    }

    public func scheduleAlarm(id: UUID, label: String, categoryName: String, body: String, fireDate: Date) {
        let configuration = Self.configuration(id: id, label: label, categoryName: categoryName, remaining: Int(fireDate.timeIntervalSinceNow.rounded()))
        Task { try? await AlarmManager.shared.schedule(id: id, configuration: configuration) }
    }

    public func cancelAlarm(id: UUID) {
        Task { try? await AlarmManager.shared.cancel(id: id) }
    }

    // 취소하지 않고 AlarmKit pause — 알람에 붙은 Live Activity 가 '일시정지됨'(Paused 표현)으로 남는다.
    // 예전엔 cancel 이라 정지하는 순간 LA 가 사라졌다.
    public func pauseAlarm(id: UUID) {
        try? AlarmManager.shared.pause(id: id)
    }

    public func resumeAlarm(id: UUID, label: String, categoryName: String, body: String, fireDate: Date) {
        do {
            try AlarmManager.shared.resume(id: id)
        } catch {
            // 시스템에 정지된 알람이 없음(예전 빌드에서 정지해 cancel 된 타이머 등) → 새로 예약
            scheduleAlarm(id: id, label: label, categoryName: categoryName, body: body, fireDate: fireDate)
        }
    }

    public func reschedulePausedAlarm(id: UUID, label: String, categoryName: String, body: String, remaining: Int) {
        let configuration = Self.configuration(id: id, label: label, categoryName: categoryName, remaining: remaining)
        Task {
            // 정지된 알람의 남은 시간은 바꿀 수 없다 → 지우고 새 남은 시간으로 예약한 뒤 바로 정지
            try? AlarmManager.shared.cancel(id: id)
            _ = try? await AlarmManager.shared.schedule(id: id, configuration: configuration)
            try? AlarmManager.shared.pause(id: id)
        }
    }

    private static func configuration(
        id: UUID,
        label: String,
        categoryName: String,
        remaining: Int
    ) -> AlarmManager.AlarmConfiguration<CareTimerAlarmMetadata> {
        let remaining = max(1, remaining)
        let tint = Color(red: 0.937, green: 0.267, blue: 0.267)   // 빨강 #EF4444 (경고·알람)

        // 분류 태그 + 처치명을 헤드라인으로: "[처치] 수혈 바이탈".
        // 완료 버튼 텍스트·체크마크를 빨강(#EF4444)으로 — 전체화면 알람에서 색 넣을 수 있는 텍스트.
        let alert = AlarmPresentation.Alert(
            title: "❗ [\(categoryName)] \(label)",
            stopButton: AlarmButton(text: "완료", textColor: tint, systemImageName: "checkmark")
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
            metadata: CareTimerAlarmMetadata(label: label, categoryName: categoryName, duration: remaining),
            tintColor: tint
        )
        // 울림 방식: 소리=기본 알람음+진동 / 진동·무음=무음 사운드 파일(소리 없음, 시스템 진동은 유지).
        // (AlarmKit 알람은 발화 시 항상 진동하므로 무음도 진동은 남음 — AlarmVibeDemo 검증)
        let useSound = RingModeStore.shared.current == .sound

        return AlarmManager.AlarmConfiguration(
            countdownDuration: Alarm.CountdownDuration(preAlert: TimeInterval(remaining), postAlert: nil),
            schedule: nil,
            attributes: attributes,
            stopIntent: TimerStopIntent(id: id.uuidString),
            sound: useSound ? .default : .named("silence.caf")
        )
    }

    private static func map(_ state: AlarmManager.AuthorizationState) -> TimerAlarmAuthorizationStatus {
        switch state {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }
}
