import XCTest
import Combine
@testable import Domain

// 시스템 알람(AlarmKit)이 만료 카드의 기준이다 (NM-635) —
// 앱 밖에서 끈 알람은 시스템에서 사라지므로, 만료됐는데 알람이 없는 타이머는 앱이 지운다.
final class TimerSystemAlarmSyncTests: XCTestCase {

    private var scheduler: FakeAlarmScheduler!
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        scheduler = FakeAlarmScheduler()
        cancellables = []
    }

    private func makeUseCase(_ timers: [TreatmentTimerModel]) -> (DefaultTimerUseCase, TimersRepository) {
        let repository = TimersRepository(timers: timers)
        return (DefaultTimerUseCase(repository: repository, alarmScheduler: scheduler), repository)
    }

    private func timer(_ label: String, endsIn seconds: TimeInterval, state: TreatmentTimerState = .running) -> TreatmentTimerModel {
        TreatmentTimerModel(label: label, category: .examination, duration: 5, endAt: Date().addingTimeInterval(seconds), state: state)
    }

    func test_만료됐는데_알람이_없으면_앱_밖_완료로_지운다() {
        let ringing = timer("울림", endsIn: -10, state: .ringing)
        let expired = timer("만료", endsIn: -1)
        let (useCase, repository) = makeUseCase([ringing, expired])
        scheduler.live = []
        var ended: [TimerEndInfo] = []
        useCase.timerEnded.sink { ended.append($0) }.store(in: &cancellables)

        useCase.syncWithSystemAlarms()

        XCTAssertTrue(useCase.timers.value.isEmpty)
        XCTAssertTrue(repository.timers.isEmpty)
        XCTAssertEqual(ended.count, 2)
        XCTAssertTrue(ended.allSatisfy { $0.reason == .completed && $0.endedOutsideApp })
    }

    func test_알람이_울리는_중이면_만료_카드를_남긴다() {
        let ringing = timer("울림", endsIn: -10, state: .ringing)
        let (useCase, _) = makeUseCase([ringing])
        scheduler.live = [ringing.id]

        useCase.syncWithSystemAlarms()

        XCTAssertEqual(useCase.timers.value.map(\.id), [ringing.id])
    }

    func test_울리기_전이나_일시정지_타이머는_알람이_없어도_건드리지_않는다() {
        let running = timer("진행", endsIn: 60)
        var paused = timer("정지", endsIn: -10, state: .paused)
        paused.remaining = 30
        let (useCase, _) = makeUseCase([running, paused])
        scheduler.live = []

        useCase.syncWithSystemAlarms()

        XCTAssertEqual(Set(useCase.timers.value.map(\.id)), [running.id, paused.id])
    }

    func test_알람_목록을_모르면_정리하지_않는다() {
        let ringing = timer("울림", endsIn: -10, state: .ringing)
        let (useCase, _) = makeUseCase([ringing])
        scheduler.live = nil

        useCase.syncWithSystemAlarms()

        XCTAssertEqual(useCase.timers.value.count, 1)
    }
}

private final class FakeAlarmScheduler: TimerAlarmScheduling {
    var live: Set<UUID>?

    func requestAuthorization() -> AnyPublisher<Bool, Never> { Just(true).eraseToAnyPublisher() }
    func authorizationStatus() -> AnyPublisher<TimerAlarmAuthorizationStatus, Never> { Just(.authorized).eraseToAnyPublisher() }
    func scheduleAlarm(id: UUID, label: String, categoryName: String, body: String, fireDate: Date) {}
    func cancelAlarm(id: UUID) {}
    func pauseAlarm(id: UUID) {}
    func resumeAlarm(id: UUID, label: String, categoryName: String, body: String, fireDate: Date) {}
    func reschedulePausedAlarm(id: UUID, label: String, categoryName: String, body: String, remaining: Int) {}
    func liveAlarmIDs() -> Set<UUID>? { live }
}

private final class TimersRepository: TimerRepositoryProtocol {
    var timers: [TreatmentTimerModel]

    init(timers: [TreatmentTimerModel]) { self.timers = timers }

    func loadTimers() -> [TreatmentTimerModel] { timers }
    func saveTimers(_ timers: [TreatmentTimerModel]) { self.timers = timers }
    func loadPresets() -> [TimerPresetModel] { [] }
    func savePresets(_ presets: [TimerPresetModel]) {}
    func setAlarmAuthorized(_ authorized: Bool) {}
    func alarmAuthorizedFlag() -> Bool? { nil }
}
