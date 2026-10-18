import XCTest
import Combine
@testable import Domain

// 프리셋 드래그 정렬(NM-613) — 저장 순서가 곧 노출 순서다.
final class TimerPresetOrderTests: XCTestCase {

    private var repository: InMemoryTimerRepository!
    private var useCase: DefaultTimerUseCase!

    override func setUp() {
        super.setUp()
        repository = InMemoryTimerRepository(presets: ["A", "B", "C", "D"].map {
            TimerPresetModel(label: $0, category: .medication, duration: 60)
        })
        useCase = DefaultTimerUseCase(repository: repository, alarmScheduler: NoopAlarmScheduler())
    }

    private var labels: [String] { useCase.presets.value.map(\.label) }

    func test_movePreset_down_insertsAtTargetIndex() {
        useCase.movePreset(id: useCase.presets.value[0].id, to: 2)
        XCTAssertEqual(labels, ["B", "C", "A", "D"])
        XCTAssertEqual(repository.presets.map(\.label), ["B", "C", "A", "D"])
    }

    func test_movePreset_up_insertsAtTargetIndex() {
        useCase.movePreset(id: useCase.presets.value[3].id, to: 0)
        XCTAssertEqual(labels, ["D", "A", "B", "C"])
    }

    func test_movePreset_outOfRange_clampsToEnds() {
        useCase.movePreset(id: useCase.presets.value[1].id, to: 99)
        XCTAssertEqual(labels, ["A", "C", "D", "B"])
        useCase.movePreset(id: useCase.presets.value[2].id, to: -1)
        XCTAssertEqual(labels, ["D", "A", "C", "B"])
    }

    func test_movePreset_sameIndexOrUnknownID_doesNotSave() {
        useCase.movePreset(id: useCase.presets.value[1].id, to: 1)
        useCase.movePreset(id: UUID(), to: 0)
        XCTAssertEqual(labels, ["A", "B", "C", "D"])
        XCTAssertEqual(repository.savePresetsCount, 0)
    }
}

private final class InMemoryTimerRepository: TimerRepositoryProtocol {
    var presets: [TimerPresetModel]
    var savePresetsCount = 0

    init(presets: [TimerPresetModel]) { self.presets = presets }

    func loadTimers() -> [TreatmentTimerModel] { [] }
    func saveTimers(_ timers: [TreatmentTimerModel]) {}
    func loadPresets() -> [TimerPresetModel] { presets }
    func savePresets(_ presets: [TimerPresetModel]) {
        self.presets = presets
        savePresetsCount += 1
    }
    func setAlarmAuthorized(_ authorized: Bool) {}
    func alarmAuthorizedFlag() -> Bool? { nil }
}

private struct NoopAlarmScheduler: TimerAlarmScheduling {
    func requestAuthorization() -> AnyPublisher<Bool, Never> { Just(true).eraseToAnyPublisher() }
    func authorizationStatus() -> AnyPublisher<TimerAlarmAuthorizationStatus, Never> { Just(.authorized).eraseToAnyPublisher() }
    func scheduleAlarm(id: UUID, label: String, categoryName: String, body: String, fireDate: Date) {}
    func cancelAlarm(id: UUID) {}
    func pauseAlarm(id: UUID) {}
    func resumeAlarm(id: UUID, label: String, categoryName: String, body: String, fireDate: Date) {}
    func reschedulePausedAlarm(id: UUID, label: String, categoryName: String, body: String, remaining: Int) {}
}
