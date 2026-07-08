import WatchConnectivity
import TimerDomain

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published private(set) var isReachable: Bool = false

    /// 폰에서 받은 최신 동기화 스냅샷 — 타이머·프리셋 목록의 단일 소스.
    /// 계약(NM-269): snapshotAt 최신이 이긴다. 오래된 스냅샷은 버린다.
    @Published private(set) var snapshot: TimerSyncSnapshot?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ message: [String: Any]) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    /// 수신 딕셔너리에서 스냅샷을 복원해 최신이면 반영. applicationContext·message 공용.
    fileprivate func apply(_ payload: [String: Any]) {
        guard let incoming = TimerSyncSnapshot.decode(fromWCPayload: payload) else { return }
        // 최신 snapshotAt 만 채택 — 늦게 도착한 오래된 스냅샷이 최신 상태를 덮지 않게.
        if let current = snapshot, incoming.snapshotAt <= current.snapshotAt { return }
        snapshot = incoming
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: (any Error)?) {
        // 활성화 시점에 폰이 마지막으로 올려둔 applicationContext를 즉시 반영(콜드 스타트 복구).
        let context = session.receivedApplicationContext
        Task { @MainActor in
            self.isReachable = session.isReachable
            self.apply(context)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.isReachable = session.isReachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.apply(message) }
    }
}
