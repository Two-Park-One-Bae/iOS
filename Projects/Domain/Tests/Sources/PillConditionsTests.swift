import XCTest
@testable import Domain

/// 수정 화면 조건 규칙 (NM-513). 정본: spec candidate.md 「모델값과 사용자값」 · 「마크 유무」, DESIGN.pen NM-490.
///
/// 규칙마다 테스트 하나 — 규칙이 바뀌면 여기서 먼저 깨져야 한다.
final class PillConditionsTests: XCTestCase {

    private let model = PillModelOutput(
        attributeToken: "tok",
        colorHexes: ["#FFFFFF", "#F2C94C"],
        shape: .oval,
        formulation: .tablet,
        frontImprint: "AX",
        frontMarkScore: 0.93,
        frontEmbedding: [0.1, 0.2],
        frontEmbeddingModel: "mark-v1"
    )

    // MARK: - 초기 상태

    func test_처음에는_외형이_모두_전체다_모델값은_보여주기만_한다() {
        let c = PillConditions(model: model)
        XCTAssertEqual(c.colors, .all)
        XCTAssertEqual(c.shape, .all)
        XCTAssertEqual(c.formulation, .all)
        XCTAssertEqual(c.colors.tone, .estimate)
    }

    func test_처음_각인은_확신_글자_모델값이고_호박색이다() {
        let c = PillConditions(model: model)
        XCTAssertEqual(c.front.imprint, .value("AX", source: .model))
        XCTAssertEqual(c.front.imprint.tone, .confirmed)
    }

    func test_확신_글자가_없으면_각인은_전체다_모델은_빈_문자열을_내지_않는다() {
        for imprint in [nil, ""] as [String?] {
            let c = PillConditions(model: PillModelOutput(frontImprint: imprint))
            XCTAssertEqual(c.front.imprint, .all, "\(String(describing: imprint))")
        }
    }

    func test_각인이_있으면_마크_점수가_080_이상일_때만_있음() {
        let mark = { (score: Float?) in PillConditions(model: PillModelOutput(frontImprint: "AX", frontMarkScore: score)).front.mark }
        XCTAssertEqual(mark(0.80), .present(source: .model))
        XCTAssertEqual(mark(0.79), .all)
        XCTAssertEqual(mark(0.60), .all)
        XCTAssertEqual(mark(nil), .all)
    }

    func test_각인이_없으면_마크_점수가_060_이상이면_있음() {
        // 확신 글자가 없는 면(보류·판독 실패 포함)은 각인 없음으로 본다 (NM-527).
        let mark = { (score: Float?) in PillConditions(model: PillModelOutput(frontImprint: nil, frontMarkScore: score)).front.mark }
        XCTAssertEqual(mark(0.60), .present(source: .model))
        XCTAssertEqual(mark(0.79), .present(source: .model))
        XCTAssertEqual(mark(0.59), .all)
        XCTAssertEqual(mark(nil), .all)
    }

    func test_모델은_마크_없음을_만들지_않는다() {
        XCTAssertNotEqual(PillConditions(model: PillModelOutput(frontMarkScore: 0.0)).front.mark, .none)
    }

    func test_구분선은_모델이_없어_항상_전체로_시작한다() {
        XCTAssertEqual(PillConditions(model: model).front.dividingLine, .all)
    }

    func test_뒷면은_사진이_없어_모두_전체다() {
        XCTAssertEqual(PillConditions(model: model).back, FaceConditions())
    }

    func test_추출_실패면_서버_값은_버리고_기기_값만_남는다() {
        let failed = PillAttributeModel(pillId: "1", attributeToken: "x", colorHexes: ["#000000"],
                                          shape: .round, formulation: .tablet, error: "EXTRACTION_FAILED")
        let output = PillModelOutput(attribute: failed, frontImprint: "AX")
        XCTAssertNil(output.attributeToken)
        XCTAssertEqual(output.colorHexes, [])
        XCTAssertNil(output.shape)
        XCTAssertEqual(output.frontImprint, "AX")
    }

    // MARK: - 사용자 입력

    func test_모델값과_같은_각인을_입력해도_사용자값이다() {
        var c = PillConditions(model: model)
        c.submitImprint("AX", on: .front)
        XCTAssertEqual(c.front.imprint, .value("AX", source: .user))
    }

    func test_각인을_비우고_확인하면_없음이다() {
        var c = PillConditions(model: model)
        c.submitImprint("  ", on: .front)
        XCTAssertEqual(c.front.imprint, .none)
        XCTAssertEqual(c.front.imprint.tone, .confirmed)
    }

    func test_앞면을_고쳐도_뒷면은_그대로다_면_단위() {
        var c = PillConditions(model: model)
        c.submitImprint("B", on: .back)
        XCTAssertEqual(c.front.imprint, .value("AX", source: .model))
        XCTAssertEqual(c.back.imprint, .value("B", source: .user))
    }

    func test_외형을_고르면_호박색이고_빈_선택은_전체로_돌아간다() {
        var c = PillConditions(model: model)
        c.setColors([.white])
        XCTAssertEqual(c.colors, .user([.white]))
        XCTAssertEqual(c.colors.tone, .confirmed)
        c.setColors([])
        XCTAssertEqual(c.colors, .all)
    }

    // MARK: - 되돌리기

    func test_각인_되돌리기는_모델_확신_글자로_돌아간다() {
        var c = PillConditions(model: model)
        c.submitImprint("ZZ", on: .front)
        c.revertImprint(on: .front)
        XCTAssertEqual(c.front.imprint, .value("AX", source: .model))
    }

    func test_모델_글자가_없으면_각인_되돌리기는_전체다() {
        var c = PillConditions(model: model)
        c.submitImprint("B", on: .back)
        c.revertImprint(on: .back)
        XCTAssertEqual(c.back.imprint, .all)
    }

    func test_외형_되돌리기는_메뉴의_전체다() {
        var c = PillConditions(model: model)
        c.setShape(.round)
        c.setShape(nil)
        XCTAssertEqual(c.shape, .all)
    }

    // MARK: - 후보 조회 조건

    func test_모델이_추정한_외형은_조건으로_보내지_않는다() {
        let q = PillConditions(model: model).query
        XCTAssertEqual(q.colors, [])
        XCTAssertNil(q.shape)
        XCTAssertNil(q.formulation)
    }

    func test_사용자가_고른_외형만_보낸다() {
        var c = PillConditions(model: model)
        c.setColors([.white, .yellow])
        c.setShape(.round)
        c.setFormulation(.softCapsule)
        let q = c.query
        XCTAssertEqual(q.colors, [.white, .yellow])
        XCTAssertEqual(q.shape, .round)
        XCTAssertEqual(q.formulation, .softCapsule)
    }

    func test_토큰은_사용자가_무엇을_고쳤든_항상_보낸다() {
        var c = PillConditions(model: model)
        c.setShape(.round)
        c.submitImprint("Q", on: .front)
        XCTAssertEqual(c.query.attributeToken, "tok")
        XCTAssertNil(c.query.withoutToken.attributeToken)
    }

    func test_각인_출처가_요청에_실린다() {
        var c = PillConditions(model: model)
        XCTAssertEqual(c.query.front?.imprint, "AX")
        XCTAssertEqual(c.query.front?.imprintSource, .model)
        c.submitImprint("AX", on: .front)
        XCTAssertEqual(c.query.front?.imprintSource, .user)
    }

    func test_각인_없음은_빈_문자열_사용자값이다() {
        var c = PillConditions(model: model)
        c.submitImprint("", on: .front)
        XCTAssertEqual(c.query.front?.imprint, "")
        XCTAssertEqual(c.query.front?.imprintSource, .user)
    }

    func test_마크_유무_접기_있음은_true_없음은_false_전체는_nil() {
        var c = PillConditions(model: model)
        XCTAssertEqual(c.query.front?.hasMark, true)
        c.setMark(.none, on: .front)
        XCTAssertEqual(c.query.front?.hasMark, false)
        c.setMark(.all, on: .front)
        XCTAssertNil(c.query.front?.hasMark)
    }

    func test_구분선_없음은_NONE이다() {
        var c = PillConditions(model: model)
        c.setDividingLine(.none, on: .back)
        XCTAssertEqual(c.query.back?.dividingLine, PillDividingLineQuery.none)
        c.setDividingLine(.value(.minus), on: .back)
        XCTAssertEqual(c.query.back?.dividingLine, .minus)
    }

    func test_조건이_하나도_없는_면은_보내지_않는다() {
        XCTAssertNil(PillConditions(model: model).query.back)
        XCTAssertNil(PillConditions(model: .empty).query.front)
    }

    func test_임베딩은_앞면에만_실린다() {
        let q = PillConditions(model: model).query
        XCTAssertEqual(q.front?.embedding, [0.1, 0.2])
        XCTAssertNil(q.back)
    }

    /// 임베딩은 걸러진 후보의 최종 재정렬용이라 마크 조건과 무관하다.
    func test_마크를_없음이나_전체로_골라도_임베딩은_보낸다() {
        for mark in [MarkCondition.none, .all, .present(source: .user)] {
            var c = PillConditions(model: model)
            c.setMark(mark, on: .front)
            XCTAssertEqual(c.query.front?.embedding, [0.1, 0.2], "\(mark)")
        }
    }

    /// 임베딩을 보내면 뽑은 모델 버전도 함께(spec NM-533) — 없으면 서버가 400.
    func test_임베딩을_보내면_마크_모델_버전도_함께_보낸다() {
        XCTAssertEqual(PillConditions(model: model).query.markEmbeddingModel, "mark-v1")
    }

    func test_임베딩이_없으면_마크_모델_버전도_없다() {
        let noEmbedding = PillModelOutput(attributeToken: "tok", frontEmbeddingModel: "mark-v1")
        XCTAssertNil(PillConditions(model: noEmbedding).query.markEmbeddingModel)
    }

    func test_수동_추가는_토큰도_조건도_없다() {
        let q = PillConditions(model: .empty).query
        XCTAssertNil(q.attributeToken)
        XCTAssertEqual(q, PillCandidateQuery(attributeToken: nil, colors: [], shape: nil, formulation: nil, front: nil, back: nil))
    }
}
