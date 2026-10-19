import XCTest
@testable import Domain

/// 사진 id 는 UUID v7 이다 (NM-568) — 서버가 앞 48비트(만든 시각)로 원본 키의 날짜를 만든다.
final class PillImageIdTests: XCTestCase {

    func test_UUID_v7_소문자_형식이다() {
        let id = PillImageId.make()
        // 서버 검사와 같은 식(PillImageIds.V7_PATTERN)
        let pattern = "^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
        XCTAssertNotNil(id.range(of: pattern, options: .regularExpression), id)
    }

    func test_앞_48비트는_만든_시각_밀리초다() throws {
        let date = Date(timeIntervalSince1970: 1_760_000_000.5)
        let id = PillImageId.make(at: date)
        let hex = id.replacingOccurrences(of: "-", with: "").prefix(12)
        XCTAssertEqual(UInt64(hex, radix: 16), 1_760_000_000_500)
    }

    func test_같은_시각이어도_겹치지_않는다() {
        let date = Date()
        let ids = Set((0..<1000).map { _ in PillImageId.make(at: date) })
        XCTAssertEqual(ids.count, 1000)
    }
}
