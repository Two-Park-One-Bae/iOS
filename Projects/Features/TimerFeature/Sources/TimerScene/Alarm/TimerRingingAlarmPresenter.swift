import UIKit
import Combine
import Core
import Domain

// 포그라운드 만료 풀스크린 알람 + 백그라운드 만료 사운드 (ZFXjS, iOS 26 미만).
// UseCase의 timers를 구독해 ringing 타이머가 생기면:
//  - 사운드는 fg/bg 무관 항상 루핑 재생(BackgroundAudioKeepAlive가 백그라운드 생명을 연장한 상태).
//  - 풀스크린 UI는 포그라운드에서만 present. 백그라운드 복귀 시 evaluate 재호출로 UI를 보충.
// [완료]로 끈다. iOS 26에서는 AlarmKit이 시스템 알람을 담당하므로 activate하지 않는다.
public final class TimerRingingAlarmPresenter {

    public static let shared = TimerRingingAlarmPresenter()

    private var cancellables = Set<AnyCancellable>()
    private var presentedID: UUID?
    private weak var currentVC: TimerRingingAlarmViewController?
    private var useCase: TimerUseCase?

    public func activate() {
        let uc = DIContainer.shared.resolve(TimerUseCase.self)
        useCase = uc
        uc.timers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timers in self?.evaluate(timers) }
            .store(in: &cancellables)

        // 앱 활성화 시 재평가 — 콜드런치 첫 이벤트 누락, 백그라운드(사운드만) 복귀 후 UI 보충 커버.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let value = self.useCase?.timers.value else { return }
            self.evaluate(value)
        }
    }

    // MARK: - Evaluate

    private func evaluate(_ timers: [TreatmentTimerModel]) {
        let ringing = timers.filter { $0.state == .ringing }.sorted { $0.endAt < $1.endAt }

        // ringing이 없으면 정리
        guard let target = ringing.first else {
            if let presenting = currentVC {
                currentVC = nil
                presenting.dismiss(animated: true)
            }
            if presentedID != nil {
                presentedID = nil
                AlarmSoundPlayer.shared.stop()
            }
            return
        }

        // 울림 방식: 소리 모드일 때만 비프 재생. 진동·무음은 소리 없음.
        if RingModeStore.shared.current == .sound {
            AlarmSoundPlayer.shared.start()
        } else {
            AlarmSoundPlayer.shared.stop()
        }

        // 같은 타이머 유지 — 포그라운드인데 UI가 없으면 보충 (백그라운드 사운드만 상태에서 복귀 등)
        if presentedID == target.id {
            if currentVC == nil, let top = topMostVC() {
                presentUI(target, on: top)
            }
            return
        }

        // 타깃이 바뀜 → 기존 UI 닫고 새로 표시
        presentedID = target.id
        if let presenting = currentVC {
            currentVC = nil
            presenting.dismiss(animated: true) { [weak self] in
                guard let self, let top = self.topMostVC() else { return }
                self.presentUI(target, on: top)
            }
        } else if let top = topMostVC() {
            presentUI(target, on: top)
        }
        // 백그라운드(topMostVC nil)면 사운드만. 포그라운드 복귀 시 evaluate 재호출로 UI 보충.
    }

    private func presentUI(_ timer: TreatmentTimerModel, on top: UIViewController) {
        let vc = TimerRingingAlarmViewController(timer: timer)
        vc.onComplete = { [weak self] in self?.apply(.complete(timer.id)) }
        currentVC = vc
        top.present(vc, animated: true)
    }

    private enum Action { case complete(UUID) }

    private func apply(_ action: Action) {
        guard let useCase else { return }
        switch action {
        case .complete(let id): useCase.remove(id: id)
        }
        // UseCase 갱신 → timers 이벤트 → evaluate가 사운드/UI 정리
    }

    // MARK: - Window

    private func topMostVC() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              var top = window.rootViewController else { return nil }
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
