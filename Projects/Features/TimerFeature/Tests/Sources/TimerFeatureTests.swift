import XCTest
@testable import TimerFeature
import Domain

final class TimerFeatureTests: XCTestCase {

    func test_timerFormat_duration() {
        XCTAssertEqual(TimerFormat.duration(15 * 60), "15분")
        XCTAssertEqual(TimerFormat.duration(2 * 60 * 60), "2시간")
        XCTAssertEqual(TimerFormat.duration(90 * 60), "1시간 30분")
        XCTAssertEqual(TimerFormat.duration(90), "1분 30초")
    }

    func test_timerFormat_countdown() {
        XCTAssertEqual(TimerFormat.countdown(754), "12:34")
        XCTAssertEqual(TimerFormat.countdown(4360), "1:12:40")
        XCTAssertEqual(TimerFormat.countdown(0), "00:00")
    }
}
