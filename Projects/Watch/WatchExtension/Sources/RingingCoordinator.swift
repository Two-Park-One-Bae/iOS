import SwiftUI
import WatchKit
import TimerDomain

// 애플워치 기본 타이머처럼 — 만료 시 시스템 알람 + 지속 진동 + e0iD7H 화면.
//
// 핵심은 WKExtendedRuntimeSession(alarm 모드): running 타이머의 endAt 에 세션을 예약하면
// 시계 화면·손목 내림·앱 종료 상태여도 그 시각에 워치가 깨어나 알람을 띄우고 끌 때까지 진동한다.
// (예약 start(at:) 은 앱이 포그라운드일 때만 가능 — 워치 앱을 본 타이머가 대상)
//
// 앱이 떠 있을 때는 자체 시계(ticker)로도 만료를 잡아 e0iD7H 오버레이 + 반복 햅틱을 띄운다.
// 앱을 한 번도 안 연 폰-시작 타이머는 WatchNotificationScheduler(로컬 알림)가 보조로 울린다.
@MainActor
final class RingingCoordinator: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {

    @Published var ringing: TreatmentTimerModel?

    private var timers: [TreatmentTimerModel] = []
    private var haptics: Task<Void, Never>?
    private var ticker: Task<Void, Never>?

    private var session: WKExtendedRuntimeSession?
    private var armedId: UUID?
    private var armedEndAt: Date?

    // MARK: 입력

    func sync(_ snapshot: TimerSyncSnapshot?) {
        timers = snapshot?.timers ?? []
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

    // MARK: 알람 세션 (기본 타이머 동작)

    // 표시 중이 아니면, 가장 먼저 만료될 running 타이머의 endAt 에 세션을 (재)예약.
    private func arm() {
        guard ringing == nil else { return }   // 울리는 중엔 현재 세션 유지
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

    // MARK: WKExtendedRuntimeSessionDelegate — 예약 시각 도달

    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in
            let fired = timers.first { $0.id == armedId }
            present(fired ?? placeholder(), sessionHaptic: true)
            // 끌 때까지 반복 진동(기본 타이머 알람과 동일).
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
            if session === extendedRuntimeSession {
                session = nil; armedId = nil; armedEndAt = nil
            }
        }
    }

    // armedId 에 해당하는 스냅샷이 아직 없을 때 표시용 폴백.
    private func placeholder() -> TreatmentTimerModel {
        TreatmentTimerModel(label: "타이머 종료", category: .treatment, duration: 0, endAt: Date(), state: .ringing)
    }
}
