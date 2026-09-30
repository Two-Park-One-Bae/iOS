import XCTest
import Domain
@testable import DrugIdentificationFeature

/// 기기 각인·마크 결과가 수정 화면 앞면 조건과 후보 조회 임베딩으로 이어지는가 (NM-459 · NM-512).
final class IdentifiedPillModelOutputTests: XCTestCase {

    private let embedding = [Float](repeating: 0.01, count: 8 * 768)

    private func pill(attribute: PillAttributeModel? = nil, face: PillFaceModelResult?) -> IdentifiedPill {
        IdentifiedPill(index: 1, pillId: "7", thumbnail: nil, boundingBox: .zero, attribute: attribute, faceModel: face)
    }

    func test_확신_글자와_마크_있음이_앞면_모델값으로_시작한다() {
        let face = PillFaceModelResult(imprint: "AX", markScore: 0.93, embedding: embedding)
        let conditions = PillConditions(model: pill(face: face).modelOutput)
        XCTAssertEqual(conditions.front.imprint, .value("AX", source: .model))
        XCTAssertEqual(conditions.front.mark, .present(source: .model))
    }

    func test_마크_임계는_같은_면의_각인_유무로_나뉜다() {
        // NM-527 — 각인 확신 글자가 있으면 0.80, 없으면 0.60.
        let withImprint = PillFaceModelResult(imprint: "AX", markScore: 0.70, embedding: embedding)
        let withoutImprint = PillFaceModelResult(imprint: nil, markScore: 0.70, embedding: embedding)
        XCTAssertEqual(PillConditions(model: pill(face: withImprint).modelOutput).front.mark, .all)
        XCTAssertEqual(PillConditions(model: pill(face: withoutImprint).modelOutput).front.mark, .present(source: .model))
        XCTAssertEqual(PillConditions(model: pill(face: withoutImprint).modelOutput).query.front?.hasMark, true)
    }

    func test_임베딩은_마크_조건과_무관하게_앞면_요청에_실린다() {
        let face = PillFaceModelResult(imprint: nil, markScore: 0.10, embedding: embedding)
        let conditions = PillConditions(model: pill(face: face).modelOutput)
        XCTAssertEqual(conditions.front.imprint, .all)
        XCTAssertEqual(conditions.front.mark, .all)
        XCTAssertEqual(conditions.query.front?.embedding, embedding)
        XCTAssertNil(conditions.query.front?.hasMark)
    }

    func test_기기_결과가_없으면_지금처럼_전체로_시작한다() {
        let output = pill(face: nil).modelOutput
        XCTAssertEqual(output, .empty)
        XCTAssertEqual(PillConditions(model: output).front.imprint, .all)
    }
}
