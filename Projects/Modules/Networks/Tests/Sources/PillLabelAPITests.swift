import XCTest
import Moya
@testable import Networks

/// 학습용 라벨 경로 · 본문 (NM-568). 정본: spec `api/domains/label.md` 「새 앱이 보내는 것」.
final class PillLabelAPITests: XCTestCase {

    private let imageId = "01928f3a-7b2c-7d4e-8f00-123456789abc"

    func test_라벨은_PUT_사진id_labels_번호() {
        let api = PillAPI.savePillLabel(imageId: imageId, pillIndex: 3, request: label(manual: false))
        XCTAssertEqual(api.apiVersion, "v0")
        XCTAssertEqual(api.path, "/pill-images/\(imageId)/labels/3")
        XCTAssertEqual(api.method, .put)
    }

    func test_지운_번호는_PATCH_사진id_segmentation() throws {
        let api = PillAPI.savePillSegmentation(imageId: imageId, request: PillSegmentationSaveRequest(deletedIndexes: [2, 5]))
        XCTAssertEqual(api.path, "/pill-images/\(imageId)/segmentation")
        XCTAssertEqual(api.method, .patch)
        XCTAssertEqual(try json(api)["deletedIndexes"] as? [Int], [2, 5])
    }

    func test_업로드_URL_발급은_imageId_가_있으면_본문에_싣는다() throws {
        XCTAssertEqual(try json(PillAPI.pillImagesUploadUrl(imageId: imageId))["imageId"] as? String, imageId)
        guard case .requestPlain = PillAPI.pillImagesUploadUrl(imageId: nil).task else {
            return XCTFail("imageId 가 없으면 본문 없이 보낸다 — 서버가 uuid 를 만든다")
        }
    }

    func test_수동_추가_라벨은_model_키가_없다() throws {
        let body = try json(PillAPI.savePillLabel(imageId: imageId, pillIndex: 100, request: label(manual: true)))
        XCTAssertEqual(body["manual"] as? Bool, true)
        XCTAssertNil(body["model"], "수동 추가에 model 을 보내면 400")
        XCTAssertNotNil(body["userInput"])
    }

    func test_속성_추출은_라벨_값이_없으면_키째_빠진다() throws {
        let plain = PillAttributeRequest(items: [
            PillAttributeItemRequest(pillId: "7", croppedImage: PillImageRequest(mimeType: "image/png", data: "AA=="))
        ])
        let body = try json(PillAPI.pillAttributes(request: plain))
        XCTAssertNil(body["imageId"])
        let item = try XCTUnwrap((body["items"] as? [[String: Any]])?.first)
        XCTAssertNil(item["box"])
        XCTAssertNil(item["score"])
    }

    func test_속성_추출에_라벨_값을_싣는다() throws {
        let request = PillAttributeRequest(
            items: [PillAttributeItemRequest(
                pillId: "7",
                croppedImage: PillImageRequest(mimeType: "image/png", data: "AA=="),
                box: [10, 20, 30, 40],
                score: 0.9
            )],
            imageId: imageId, imageWidth: 2048, imageHeight: 2048, segModel: "seg-v1"
        )
        let body = try json(PillAPI.pillAttributes(request: request))
        XCTAssertEqual(body["imageId"] as? String, imageId)
        XCTAssertEqual(body["imageWidth"] as? Int, 2048)
        XCTAssertEqual(body["segModel"] as? String, "seg-v1")
        let item = try XCTUnwrap((body["items"] as? [[String: Any]])?.first)
        XCTAssertEqual(item["box"] as? [Int], [10, 20, 30, 40])
        XCTAssertEqual(item["score"] as? Double, 0.9)
    }

    // MARK: - Helpers

    private func label(manual: Bool) -> PillLabelRequest {
        let query = PillCandidateRequest(attributeToken: nil, colors: [], shape: nil, formulation: nil, front: nil, back: nil)
        return PillLabelRequest(pillCode: "200001234", manual: manual, model: manual ? nil : query, userInput: query)
    }

    private func json(_ api: PillAPI) throws -> [String: Any] {
        guard case .requestJSONEncodable(let encodable) = api.task else {
            XCTFail("JSON 본문이 아니다: \(api.task)")
            return [:]
        }
        let data = try JSONEncoder().encode(AnyEncodable(encodable))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
