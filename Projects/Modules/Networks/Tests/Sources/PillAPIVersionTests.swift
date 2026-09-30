import XCTest
@testable import Networks

/// 알약 식별(속성 추출 · 후보 조회)만 /api/v1 로 간다 — usage · 세부정보 · 업로드는 v0 그대로 (spec NM-521).
final class PillAPIVersionTests: XCTestCase {

    private let request = PillAttributeRequest(items: [])

    func test_속성_추출은_api_v1_로_간다() {
        XCTAssertTrue(PillAPI.pillAttributes(request: request).baseURL.absoluteString.hasSuffix("/api/v1"))
        XCTAssertEqual(PillAPI.pillAttributes(request: request).path, "/pill-attributes")
    }

    func test_후보_조회와_카드_조회는_api_v1_로_간다() {
        let search = PillAPI.pillCandidates(request: PillCandidateRequest(
            attributeToken: nil, colors: [], shape: nil, formulation: nil, front: nil, back: nil))
        XCTAssertTrue(search.baseURL.absoluteString.hasSuffix("/api/v1"))
        XCTAssertEqual(search.path, "/pill-candidates")

        let items = PillAPI.pillCandidateItems(pillCodes: ["A", "B"])
        XCTAssertTrue(items.baseURL.absoluteString.hasSuffix("/api/v1"))
        XCTAssertEqual(items.path, "/pill-candidates/items")
    }

    func test_나머지는_api_v0_에_남는다() {
        let v0: [PillAPI] = [.pillAttributesUsage, .pillDetails(pillCode: "A"), .pillImagesUploadUrl]
        for api in v0 {
            XCTAssertTrue(api.baseURL.absoluteString.hasSuffix("/api/v0"), "\(api)")
        }
    }

    /// style: form, explode: false — pillCodes=A,B 한 파라미터.
    func test_카드_조회는_쉼표로_이은_한_파라미터다() throws {
        guard case let .requestParameters(parameters, _) = PillAPI.pillCandidateItems(pillCodes: ["A", "B"]).task else {
            return XCTFail("쿼리 파라미터여야 한다")
        }
        XCTAssertEqual(parameters["pillCodes"] as? String, "A,B")
    }
}
