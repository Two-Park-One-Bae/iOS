import WatchConnectivity
import TimerDomain

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published private(set) var isReachable: Bool = false

    /// 폰에서 받은 최신 동기화 스냅샷 — 타이머·프리셋 목록의 단일 소스.
    /// 계약(NM-269): snapshotAt 최신이 이긴다. 오래된 스냅샷은 버린다.
    @Published private(set) var snapshot: TimerSyncSnapshot?

    /// 프리셋 시작 명령을 보내고 폰의 스냅샷을 기다리는 중 — 활성 페이지에서 "시작하는 중" 표시.
    /// 왕복(워치→폰→생성→스냅샷→워치) 지연 동안 빈 상태 대신 로딩을 보여주기 위함.
    @Published private(set) var isStarting: Bool = false
    private var startTimeout: DispatchWorkItem?
    private var startingBaseline: Int = 0   // 시작 시점의 타이머 개수 — 이보다 늘면 새 타이머 도착

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// 워치→폰 명령 전송(NM-269). 알람 예약은 폰 단독이라 워치는 명령만 보낸다.
    /// reachable 이면 즉시 message, 아니면(또는 실패 시) 큐잉되는 transferUserInfo 로 폴백.
    func send(command: TimerWatchCommand) {
        guard WCSession.isSupported(), let payload = try? command.wcPayload() else { return }
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
        // 시작 명령은 스냅샷 도착 전까지 "시작하는 중" 표시. 스냅샷이 안 오면 5초 후 자동 해제.
        if case .start = command {
            isStarting = true
            startingBaseline = snapshot?.timers.count ?? 0   // 지금 개수 기록
            startTimeout?.cancel()
            let item = DispatchWorkItem { [weak self] in self?.isStarting = false }
            startTimeout = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
        }
    }

    /// 수신 딕셔너리에서 스냅샷을 복원해 최신이면 반영. applicationContext·message 공용.
    fileprivate func apply(_ payload: [String: Any]) {
        guard let incoming = TimerSyncSnapshot.decode(fromWCPayload: payload) else { return }
        // 최신 snapshotAt 만 채택 — 늦게 도착한 오래된 스냅샷이 최신 상태를 덮지 않게.
        if let current = snapshot, incoming.snapshotAt <= current.snapshotAt { return }
        snapshot = incoming
        // 새 타이머가 스냅샷에 반영됐으면(개수 증가) "시작하는 중" 해제 — 기존 타이머가 있어도 정확.
        if isStarting, incoming.timers.count > startingBaseline {
            isStarting = false
            startTimeout?.cancel()
        }
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
