import Combine
import Foundation
import Core
import Domain

// C1 타이머 리스트 — 1초 틱으로 잔여시간 갱신 + RINGING 전이 감지
public final class TimerListViewModel {

    struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
    }

    struct Output {
        let timers: AnyPublisher<[TreatmentTimerModel], Never>
        let presets: AnyPublisher<[TimerPresetModel], Never>
        let tick: AnyPublisher<Void, Never>
        let alarmPermission: AnyPublisher<TimerAlarmAuthorizationStatus, Never>
    }

    @Injected private var useCase: TimerUseCase
    private var cancelBag = Set<AnyCancellable>()
    private let tickSubject = PassthroughSubject<Void, Never>()

    init() {}

    func transform(input: Input) -> Output {
        input.viewDidLoad
            .sink { [weak self] in self?.startTicking() }
            .store(in: &cancelBag)

        return Output(
            timers: useCase.timers.eraseToAnyPublisher(),
            presets: useCase.presets.eraseToAnyPublisher(),
            tick: tickSubject.eraseToAnyPublisher(),
            alarmPermission: useCase.alarmPermission.eraseToAnyPublisher()
        )
    }

    private func startTicking() {
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.useCase.refresh() // RUNNING & endAt 도달 → RINGING
                self?.tickSubject.send(())
            }
            .store(in: &cancelBag)
    }

    // MARK: - Actions (Coordinator/VC에서 호출)

    func start(preset: TimerPresetModel) { useCase.start(preset: preset) }
    func pauseOrResume(_ timer: TreatmentTimerModel) {
        timer.state == .paused ? useCase.resume(id: timer.id) : useCase.pause(id: timer.id)
    }
    func extendOneMinute(id: UUID) { useCase.extend(id: id, by: 60) }
    func remove(id: UUID) { useCase.remove(id: id) }
    func updateMemo(id: UUID, memo: String) { useCase.updateMemo(id: id, memo: memo) }

    func addPreset(label: String, category: TimerCategory, duration: Int) {
        useCase.addPreset(label: label, category: category, duration: duration)
    }
    func updatePreset(_ preset: TimerPresetModel) { useCase.updatePreset(preset) }
    func deletePreset(id: UUID) { useCase.deletePreset(id: id) }

    func requestAlarmPermission() { useCase.requestAlarmPermission() }
    func fetchAlarmPermission() { useCase.fetchAlarmPermission() }

    var currentPresets: [TimerPresetModel] { useCase.presets.value }
    var currentTimers: [TreatmentTimerModel] { useCase.timers.value }

    // Coordinator 구독용
    var presetsPublisher: AnyPublisher<[TimerPresetModel], Never> {
        useCase.presets.eraseToAnyPublisher()
    }
    var alarmPermissionPublisher: AnyPublisher<TimerAlarmAuthorizationStatus, Never> {
        useCase.alarmPermission.eraseToAnyPublisher()
    }
}
