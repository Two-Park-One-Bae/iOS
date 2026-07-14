import Foundation
import Combine
import AlarmKit
import SwiftUI
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
        let remaining = max(1, Int(fireDate.timeIntervalSinceNow.rounded()))
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
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: Alarm.CountdownDuration(preAlert: TimeInterval(remaining), postAlert: nil),
            schedule: nil,
            attributes: attributes,
            stopIntent: TimerStopIntent(id: id.uuidString),
            sound: .default
        )

        Task { try? await AlarmManager.shared.schedule(id: id, configuration: configuration) }
    }

    public func cancelAlarm(id: UUID) {
        Task { try? await AlarmManager.shared.cancel(id: id) }
    }

    private static func map(_ state: AlarmManager.AuthorizationState) -> TimerAlarmAuthorizationStatus {
        switch state {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }
}
