import XCTest

@testable import Data
import Domain
import Networks

/// 속성 추출 응답 매핑 (NM-513).
final class PillAttributeMapperTests: XCTestCase {

    func test_정상_응답을_도메인으로_옮긴다() throws {
        let result = try decode("""
        {"items":[{"pillId":"1","attributeToken":"t1","colorHexes":["#E6E3DD","#f2c94c"],"shape":"OVAL","formulation":"TABLET","error":null}],
         "usage":{"limit":15,"remaining":12,"resetAt":"2026-10-01T00:00:00+09:00"}}
        """).toDomain()

        XCTAssertEqual(result.items, [PillAttributeModel(pillId: "1", attributeToken: "t1",
                                                           colorHexes: ["#E6E3DD", "#f2c94c"],
                                                           shape: .oval, formulation: .tablet, error: nil)])
        XCTAssertEqual(result.usage.remaining, 12)
    }

    func test_추출_실패는_나머지가_비어_있다() throws {
        let item = try decode("""
        {"items":[{"pillId":"2","error":"EXTRACTION_FAILED"}],"usage":{"limit":15,"remaining":11,"resetAt":"2026-10-01T00:00:00+09:00"}}
        """).toDomain().items[0]

        XCTAssertEqual(item.error, "EXTRACTION_FAILED")
        XCTAssertNil(item.attributeToken)
        XCTAssertEqual(item.colorHexes, [])
    }

    /// 화면이 그대로 색으로 그리는 값이라 형식이 어긋난 것은 버린다.
    func test_형식이_어긋난_색_hex는_버린다() throws {
        let item = try decode("""
        {"items":[{"pillId":"1","attributeToken":"t","colorHexes":["#FFF","E6E3DD","#GGGGGG","#123abc"],"shape":"ROUND","formulation":"TABLET"}],
         "usage":{"limit":15,"remaining":1,"resetAt":"2026-10-01T00:00:00+09:00"}}
        """).toDomain().items[0]

        XCTAssertEqual(item.colorHexes, ["#123abc"])
    }

    /// NONE 은 요청 전용이지만 응답에 와도 죽지 않고 없음(nil)으로 둔다.
    func test_구분선_NONE은_도메인에서_없음이다() {
        XCTAssertNil(DividingLine.none.toDomain())
    }

    private func decode(_ json: String) throws -> PillAttributeResponseEntity {
        try JSONDecoder().decode(PillAttributeResponseEntity.self, from: Data(json.utf8))
    }
}
