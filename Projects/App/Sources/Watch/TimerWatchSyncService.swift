import Foundation
import WatchConnectivity
import Domain

// 폰→워치 동기화 송신부(NM-269). DefaultTimerUseCase가 타이머·프리셋 변경마다 호출한다.
// - 최신 상태는 updateApplicationContext 로 — 오프라인이어도 다음 연결 때 자동 전달·병합.
// - 앞에 있고 reachable 이면 sendMessage 로 즉시 반영.
// TimerSyncSnapshot·wcPayload 는 공용 모듈 TimerDomain(Domain 재노출) 것을 쓴다.
final class TimerWatchSyncService: NSObject, TimerWatchSyncing {
    static let shared = TimerWatchSyncService()

    // 활성화 전/미도달 시 못 보낸 최신 페이로드 — 활성화·연결 시 flush.
    private var lastPayload: [String: Any]?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sync(timers: [TreatmentTimerModel], presets: [TimerPresetModel]) {
        guard WCSession.isSupported() else { return }
        let snapshot = TimerSyncSnapshot(snapshotAt: Date(), timers: timers, presets: presets)
        guard let payload = try? snapshot.wcPayload() else { return }
        lastPayload = payload
        push(payload)
    }

    private func push(_ payload: [String: Any]) {
        let session = WCSession.default
        guard session.activationState == .activated else { return } // 활성화 후 flush
        try? session.updateApplicationContext(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }
}

extension TimerWatchSyncService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if activationState == .activated, let lastPayload {
            push(lastPayload)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable, let lastPayload {
            push(lastPayload)
        }
    }

    // iOS 전용 — 페어 워치 전환 시 세션 재활성화.
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
