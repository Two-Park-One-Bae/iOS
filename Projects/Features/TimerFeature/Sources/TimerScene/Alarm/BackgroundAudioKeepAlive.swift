import UIKit
import AVFoundation
import Combine
import Core
import Domain

// iOS 26 미만: 백그라운드에서 타이머가 도는 동안 무음 루핑 재생으로 앱 생명을 연장.
// 앱이 살아있어야 endAt에 AlarmSoundPlayer(.playback)가 무음 모드를 뚫고 크게 울릴 수 있다.
// (커스텀 방식의 핵심 — 오디오 백그라운드 모드 + AVAudioSession.playback)
// 포그라운드에서는 동작하지 않는다(포그라운드는 TimerRingingAlarmPresenter가 담당).
// 리스크: App Store 가이드 2.5.4 — 알람 목적임을 심사 메모에 명시 필요.
public final class BackgroundAudioKeepAlive {

    public static let shared = BackgroundAudioKeepAlive()

    private var player: AVAudioPlayer?
    private var cancellables = Set<AnyCancellable>()
    private var hasActiveTimer = false
    private let url = FileManager.default.temporaryDirectory.appendingPathComponent("care_keepalive.wav")

    public func activate() {
        let useCase = DIContainer.shared.resolve(TimerUseCase.self)
        useCase.timers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timers in
                self?.hasActiveTimer = timers.contains { $0.state == .running || $0.state == .ringing }
                self?.refresh()
            }
            .store(in: &cancellables)

        let nc = NotificationCenter.default
        nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        nc.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        // 백그라운드이고 활성(running/ringing) 타이머가 있을 때만 생명 연장.
        // ringing 중에도 유지 → AlarmSoundPlayer로 인계되는 순간의 갭을 없앤다.
        let isBackground = UIApplication.shared.applicationState != .active
        if isBackground && hasActiveTimer {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        guard player == nil else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)

        guard let fileURL = try? AlarmTone.write(to: url) else { return }
        do {
            let p = try AVAudioPlayer(contentsOf: fileURL)
            p.numberOfLoops = -1
            p.volume = 0   // 무음 루프 — 생명 연장 목적
            p.prepareToPlay()
            p.play()
            player = p
        } catch {
        }
    }

    private func stop() {
        guard player != nil else { return }
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
