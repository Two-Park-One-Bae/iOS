import XCTest
@testable import Networks

/// 알약 식별(속성 추출)만 /api/v1 로 간다 — usage · 세부정보 · 업로드는 v0 그대로 (spec NM-521).
final class PillAPIVersionTests: XCTestCase {

    private let request = PillAttributeRequest(items: [])

    func test_속성_추출은_api_v1_로_간다() {
        XCTAssertTrue(PillAPI.pillAttributes(request: request).baseURL.absoluteString.hasSuffix("/api/v1"))
        XCTAssertEqual(PillAPI.pillAttributes(request: request).path, "/pill-attributes")
    }

    func test_나머지는_api_v0_에_남는다() {
        let v0: [PillAPI] = [.pillAttributesUsage, .pillDetails(pillCode: "A"), .pillImagesUploadUrl]
        for api in v0 {
            XCTAssertTrue(api.baseURL.absoluteString.hasSuffix("/api/v0"), "\(api)")
        }
    }
}
