import XCTest
@testable import Domain

final class TreatmentTimerModelTests: XCTestCase {

    // MARK: - remainingSeconds

    func test_remainingSeconds_running_usesEndAtMinusNow() {
        let now = Date()
        let timer = TreatmentTimerModel(
            label: "수액",
            category: .medication,
            duration: 600,
            endAt: now.addingTimeInterval(90),
            state: .running
        )

        XCTAssertEqual(timer.remainingSeconds(at: now), 90)
    }

    func test_remainingSeconds_paused_usesFrozenRemaining() {
        let now = Date()
        let timer = TreatmentTimerModel(
            label: "수액",
            category: .medication,
            duration: 600,
            endAt: now.addingTimeInterval(-100),  // 이미 지났어도
            remaining: 42,                          // 멈춘 시점 값 고정
            state: .paused
        )

        XCTAssertEqual(timer.remainingSeconds(at: now), 42)
    }

    func test_remainingSeconds_neverNegative() {
        let now = Date()
        let timer = TreatmentTimerModel(
            label: "검사",
            category: .examination,
            duration: 300,
            endAt: now.addingTimeInterval(-30),  // 만료 지남
            state: .running
        )

        XCTAssertEqual(timer.remainingSeconds(at: now), 0)
    }

    // MARK: - TimerCategory

    func test_category_displayName() {
        XCTAssertEqual(TimerCategory.medication.displayName, "투약")
        XCTAssertEqual(TimerCategory.treatment.displayName, "처치")
        XCTAssertEqual(TimerCategory.examination.displayName, "검사")
    }
}
