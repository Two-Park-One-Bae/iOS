import XCTest

@testable import Data
import Domain
import Networks

/// 후보 조회 요청 · 응답 매핑 (NM-514).
final class PillCandidateMapperTests: XCTestCase {

    // MARK: 응답

    func test_후보_조회_응답을_도메인으로_옮긴다() throws {
        let result = try JSONDecoder().decode(PillCandidateResultEntity.self, from: Data("""
        {"ids":["A","B"],"truncated":true,"candidates":[
          {"pillCode":"A","pillName":"가","companyName":"회사","pillThumbnailUrl":"t","pillImageUrl":"i","licenseStatus":"REVOKED",
           "front":{"imprint":"TY","dividingLine":"PLUS","hasMark":true,"markCode":"M1"},
           "back":{"imprint":null,"dividingLine":"NONE","hasMark":false,"markCode":null}}]}
        """.utf8)).toDomain()

        XCTAssertEqual(result.ids, ["A", "B"])
        XCTAssertTrue(result.truncated)
        let candidate = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(candidate.licenseStatus, .revoked)
        XCTAssertEqual(candidate.front, PillFaceModel(imprint: "TY", dividingLine: .plus, hasMark: true, markCode: "M1"))
        // NONE 은 '구분선 없음' — 표시는 nil 과 같다.
        XCTAssertEqual(candidate.back, PillFaceModel(imprint: nil, dividingLine: nil, hasMark: false, markCode: nil))
    }

    func test_카드_조회는_missing_을_그대로_넘긴다() throws {
        let items = try JSONDecoder().decode(PillCandidateItemsEntity.self, from: Data("""
        {"items":[{"pillCode":"C","pillName":"다","companyName":"회사","pillThumbnailUrl":"t","pillImageUrl":"i","licenseStatus":"NORMAL",
                   "front":{"hasMark":false},"back":{"hasMark":false}}],"missing":["D"]}
        """.utf8)).toDomain()

        XCTAssertEqual(items.items.map(\.pillCode), ["C"])
        XCTAssertEqual(items.missing, ["D"])
    }

    // MARK: 요청

    func test_요청은_조건이_없는_키를_빼고_보낸다() throws {
        let query = PillCandidateQuery(
            attributeToken: "tok", colors: [.white], shape: nil, formulation: .tablet,
            front: PillFaceQuery(imprint: "TY", imprintSource: .user, dividingLine: PillDividingLineQuery.none, hasMark: nil, embedding: nil),
            back: nil
        )
        let json = try encode(query)

        XCTAssertEqual(json["attributeToken"] as? String, "tok")
        XCTAssertEqual(json["colors"] as? [String], ["WHITE"])
        XCTAssertEqual(json["formulation"] as? String, "TABLET")
        XCTAssertNil(json["shape"])
        XCTAssertNil(json["back"])
        let front = try XCTUnwrap(json["front"] as? [String: Any])
        XCTAssertEqual(front["imprint"] as? String, "TY")
        XCTAssertEqual(front["imprintSource"] as? String, "USER")
        XCTAssertEqual(front["dividingLine"] as? String, "NONE")
        XCTAssertNil(front["hasMark"])
        XCTAssertNil(front["markEmbedding"])
    }

    /// 출처만 보내면 서버가 400 — 각인이 없으면 출처도 뺀다.
    func test_각인이_없으면_출처도_보내지_않는다() throws {
        let face = PillFaceQuery(imprint: nil, imprintSource: .model, dividingLine: nil, hasMark: true, embedding: nil)
        XCTAssertNil(face.toNetwork().imprintSource)
    }

    // MARK: 마크 임베딩

    func test_임베딩은_fp16_LE_base64_로_보낸다() throws {
        var embedding = [Float](repeating: 0, count: 8 * 768)
        embedding[0] = 1
        embedding[1] = -2
        embedding[8 * 768 - 1] = 0.5
        let encoded = try XCTUnwrap(MarkEmbeddingEncoder.base64(embedding))

        XCTAssertEqual(encoded.count, 16_384)
        let bytes = try XCTUnwrap(Data(base64Encoded: encoded))
        XCTAssertEqual(bytes.count, 12_288)
        // fp16: 1.0 = 0x3C00, -2.0 = 0xC000, 0.5 = 0x3800 — little-endian 이라 낮은 바이트가 먼저.
        XCTAssertEqual(Array(bytes.prefix(4)), [0x00, 0x3C, 0x00, 0xC0])
        XCTAssertEqual(Array(bytes.suffix(2)), [0x00, 0x38])
    }

    /// 모양이 틀린 값을 보내 조회 전체가 400 이 되느니 임베딩 항만 뺀다.
    func test_길이가_8x768이_아니면_임베딩을_빼고_보낸다() {
        XCTAssertNil(MarkEmbeddingEncoder.base64([Float](repeating: 0.1, count: 768)))
    }

    /// 임베딩이 있으면 모델 버전이 필수(없으면 서버 400 INVALID_REQUEST, spec NM-533).
    func test_임베딩을_보내면_마크_모델_버전도_보낸다() throws {
        let face = PillFaceQuery(imprint: nil, imprintSource: nil, dividingLine: nil, hasMark: nil,
                                 embedding: [Float](repeating: 0.01, count: 8 * 768))
        let json = try encode(PillCandidateQuery(attributeToken: nil, colors: [], shape: nil, formulation: nil,
                                                 front: face, back: nil, markEmbeddingModel: "20260925-convnext-species"))

        XCTAssertEqual(json["markEmbeddingModel"] as? String, "20260925-convnext-species")
        XCTAssertNotNil((json["front"] as? [String: Any])?["markEmbedding"])
    }

    /// 모양이 틀려 임베딩을 뺐으면 버전도 뺀다 — 임베딩 없는 버전만으로는 의미가 없다.
    func test_임베딩이_빠지면_모델_버전도_보내지_않는다() throws {
        let face = PillFaceQuery(imprint: nil, imprintSource: nil, dividingLine: nil, hasMark: true,
                                 embedding: [Float](repeating: 0.01, count: 768))
        let json = try encode(PillCandidateQuery(attributeToken: nil, colors: [], shape: nil, formulation: nil,
                                                 front: face, back: nil, markEmbeddingModel: "20260925-convnext-species"))

        XCTAssertNil(json["markEmbeddingModel"])
        XCTAssertNil((json["front"] as? [String: Any])?["markEmbedding"])
    }

    private func encode(_ query: PillCandidateQuery) throws -> [String: Any] {
        let data = try JSONEncoder().encode(query.toNetwork())
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
