import Foundation
import WatchConnectivity
import Domain

// 폰→워치 동기화 송신부(NM-269). DefaultTimerUseCase가 타이머·프리셋 변경마다 호출한다.
// - 최신 상태는 updateApplicationContext 로 — 오프라인이어도 다음 연결 때 자동 전달·병합.
// - 앞에 있고 reachable 이면 sendMessage 로 즉시 반영.
// TimerSyncSnapshot·wcPayload 는 공용 모듈 TimerDomain(Domain 재노출) 것을 쓴다.
final class TimerWatchSyncService: NSObject, TimerWatchSyncing {
    static let shared = TimerWatchSyncService()

    /// 워치에서 온 명령 처리 — DI에서 UseCase.handleWatchCommand 로 연결(main에서 호출됨).
    var commandHandler: ((TimerWatchCommand) -> Void)?

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
        // iOS 26.1+ 는 AlarmKit이 워치까지 알람을 울리므로 워치는 자체 세션 알람을 끈다(중복 방지).
        // 미만이면 false → 워치가 자기 세션 알람으로 확실히 울린다.
        let alarmKitActive: Bool
        if #available(iOS 26.1, *) { alarmKitActive = true } else { alarmKitActive = false }
        let snapshot = TimerSyncSnapshot(
            snapshotAt: Date(), timers: timers, presets: presets, alarmKitActive: alarmKitActive
        )
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

    // 워치 명령 수신 — reachable 이면 message, 아니면 큐잉된 userInfo 로 도착.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncoming(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleIncoming(userInfo)
    }

    private func handleIncoming(_ dict: [String: Any]) {
        guard let command = TimerWatchCommand.decode(fromWCPayload: dict) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.commandHandler?(command)
        }
    }

    // iOS 전용 — 페어 워치 전환 시 세션 재활성화.
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
