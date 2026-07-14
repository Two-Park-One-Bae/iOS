import SwiftUI
import WatchKit
import TimerDomain

// 만료 알람 조율 — 폰 AlarmKit 유무에 따라 워치 자체 알람을 켤지 결정.
//
// - 폰 iOS 26.1+ (alarmKitActive=true): AlarmKit이 워치까지 울림 → 워치 세션 안 켬(중복 방지).
//     워치는 앱 열렸을 때 e0iD7H만 표시. "무슨 타이머인지"는 배너 알림(WatchNotificationScheduler).
// - 폰 iOS < 26.1 (alarmKitActive=false/nil): AlarmKit 없음 → 워치가 WKExtendedRuntimeSession(alarm)을
//     endAt 에 예약해 자체적으로 확실히 울린다(시계 화면/손목 내림에서도).
@MainActor
final class RingingCoordinator: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {

    @Published var ringing: TreatmentTimerModel?

    private var timers: [TreatmentTimerModel] = []
    private var alarmKitActive = false   // 폰이 AlarmKit으로 알람 담당(워치까지 울림)
    private var haptics: Task<Void, Never>?
    private var ticker: Task<Void, Never>?

    private var session: WKExtendedRuntimeSession?
    private var armedId: UUID?
    private var armedEndAt: Date?

    // MARK: 입력

    func sync(_ snapshot: TimerSyncSnapshot?) {
        timers = snapshot?.timers ?? []
        alarmKitActive = snapshot?.alarmKitActive ?? false
        evaluate()
        restartTicker()
        arm()
    }

    /// [완료] — 즉시 닫고 진동·세션 정지, 다음 타이머 재예약.
    func dismiss() {
        ringing = nil
        stopHaptics()
        invalidateSession()
        restartTicker()
        arm()
    }

    // MARK: 표시 (포그라운드)

    private func evaluate() {
        if let current = ringing, !timers.contains(where: { $0.id == current.id }) {
            dismiss()
            return
        }
        guard ringing == nil else { return }
        let now = Date()
        if let fired = timers.first(where: {
            $0.state == .ringing || ($0.state == .running && $0.endAt <= now)
        }) {
            present(fired, sessionHaptic: false)
        }
    }

    private func restartTicker() {
        ticker?.cancel()
        ticker = nil
        guard ringing == nil, timers.contains(where: { $0.state == .running }) else { return }
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self else { return }
                self.evaluate()
                if self.ringing != nil { return }
            }
        }
    }

    // sessionHaptic=true 면 notifyUser 가 진동을 담당(중복 방지), false 면 앱 내 반복 햅틱.
    private func present(_ timer: TreatmentTimerModel, sessionHaptic: Bool) {
        ticker?.cancel(); ticker = nil
        stopHaptics()   // 기존 반복 햅틱 정리 — 중복 방지
        ringing = timer
        if !sessionHaptic { startHaptics() }
    }

    private func startHaptics() {
        haptics?.cancel()
        haptics = Task { @MainActor in
            while !Task.isCancelled {
                WKInterfaceDevice.current().play(.notification)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    private func stopHaptics() {
        haptics?.cancel()
        haptics = nil
    }

    // MARK: 알람 세션 (폰이 AlarmKit 없을 때만)

    private func arm() {
        guard ringing == nil else { return }         // 울리는 중엔 현재 세션 유지
        guard !alarmKitActive else {                 // 폰이 AlarmKit 담당 → 워치 세션 불필요
            invalidateSession()
            return
        }
        let now = Date()
        let next = timers
            .filter { $0.state == .running && $0.endAt > now }
            .min { $0.endAt < $1.endAt }

        guard let next else { invalidateSession(); return }
        if armedId == next.id, armedEndAt == next.endAt { return }

        invalidateSession()
        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        newSession.start(at: next.endAt)   // 포그라운드에서만 유효
        session = newSession
        armedId = next.id
        armedEndAt = next.endAt
    }

    private func invalidateSession() {
        session?.invalidate()
        session = nil
        armedId = nil
        armedEndAt = nil
    }

    // MARK: WKExtendedRuntimeSessionDelegate

    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in
            let fired = timers.first { $0.id == armedId }
            present(fired ?? placeholder(), sessionHaptic: true)
            extendedRuntimeSession.notifyUser(hapticType: .notification) { _ in 1.0 }
        }
    }

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        Task { @MainActor in
            stopHaptics()   // [중단]/세션 종료 시 반복 햅틱도 정지
            if session === extendedRuntimeSession {
                session = nil; armedId = nil; armedEndAt = nil
            }
        }
    }

    private func placeholder() -> TreatmentTimerModel {
        TreatmentTimerModel(label: "타이머 종료", category: .treatment, duration: 0, endAt: Date(), state: .ringing)
    }
}
