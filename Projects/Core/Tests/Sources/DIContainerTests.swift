import XCTest
@testable import Core

final class DIContainerTests: XCTestCase {
    var sut: DIContainer!

    override func setUp() {
        super.setUp()
        sut = DIContainer.shared
    }

    func test_register_and_resolve() {
        sut.register(String.self) { "Hello" }
        let value = sut.resolve(String.self)
        XCTAssertEqual(value, "Hello")
    }
}
