import CoreML
import Foundation

public enum ImprintReaderModelError: LocalizedError {
    case missingModel

    public var errorDescription: String? {
        switch self {
        case .missingModel: return "앱 번들에서 \(ImprintReaderModel.resourceName).mlmodelc를 찾지 못했습니다."
        }
    }
}

/// 각인 판독기(CRNN, ep60 시드 1) CoreML 모델 (NM-459).
///
/// 입력 `image` [24,1,128,128] — CLAHE 를 끝낸 흑백. 출력 `logits` [32,24,37] (시간축 · 배치 · 클래스).
/// 배치 24 고정: 가변 shape 은 ANE 를 잘 못 탄다. (배율·방향) 조합을 묶어 한 번에 넘긴다.
/// 규격·전처리는 ML 레포 `models/imprint/20260907-crnn-ep60-s1/INFO.md`.
public final class ImprintReaderModel {
    static let resourceName = "Reader_s1_b24_fp32"
    public static let batchSize = 24
    public static let inputSize = 128

    public let model: MLModel

    public init() throws {
        guard let url = Bundle(for: ImprintReaderModel.self).url(forResource: Self.resourceName, withExtension: "mlmodelc") else {
            throw ImprintReaderModelError.missingModel
        }
        let config = MLModelConfiguration()
        config.computeUnits = .all
        model = try MLModel(contentsOf: url, configuration: config)
    }
}
