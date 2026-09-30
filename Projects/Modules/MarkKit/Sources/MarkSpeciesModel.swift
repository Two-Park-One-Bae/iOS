import CoreML
import Foundation

public enum MarkSpeciesModelError: LocalizedError {
    case missingModel
    case missingOutput

    public var errorDescription: String? {
        switch self {
        case .missingModel: return "앱 번들에서 \(MarkSpeciesModel.resourceName).mlmodelc를 찾지 못했습니다."
        case .missingOutput: return "마크 모델 출력(prob · embedding)을 읽지 못했습니다."
        }
    }
}

/// 마크 모델(ConvNeXt species, fp16) — 한 면에서 유무 · 종 · 임베딩을 낸다 (NM-512).
///
/// 입력 `gray` [1…8,1,224,224] — CLAHE 까지 끝낸 흑백을 0~1 로. 한 면의 8방향 회전이 배치 8.
/// 출력 `prob` [N,104] (softmax, 0 = 없음 · 103 = 기타) · `embedding` [N,768] (L2 정규화).
/// 규격·임계값은 ML 레포 `models/mark/20260925-convnext-species/INFO.md`.
public final class MarkSpeciesModel {
    static let resourceName = "Mark_b8_fp16"
    public static let maxBatch = 8
    public static let inputSize = 224

    public let model: MLModel

    /// **Neural Engine 으로 돌린다.** fp16 모델이라 ANE 에 올라간다.
    ///
    /// iPhone 12 실측(8방향 한 번): ANE 60ms · RAM +2MB, CPU 228ms, GPU 523ms(fp16 을 GPU 로 돌리면 오히려 느리다).
    /// 임베딩 정확도 차이는 작다 — PyTorch 대비 코사인 최소(Mac, 크롭 6장 × 8방향) ANE 0.9993 · GPU 0.9995.
    /// 전처리 한 단계(흑백 변환)만 달라도 유무 점수가 0.2 움직이는 것에 비하면 무시할 수 있다(INFO.md).
    /// 첫 적재에 ANE 컴파일이 수 초 걸리니 앱이 미리 열어 둔다.
    /// - Parameter url: 컴파일된 `.mlmodelc`. nil 이면 이 프레임워크 번들에서 찾는다(대조 도구가 경로를 준다).
    public init(url: URL? = nil, computeUnits: MLComputeUnits = .cpuAndNeuralEngine) throws {
        guard let url = url ?? Bundle(for: MarkSpeciesModel.self).url(forResource: Self.resourceName, withExtension: "mlmodelc") else {
            throw MarkSpeciesModelError.missingModel
        }
        let config = MLModelConfiguration()
        config.computeUnits = computeUnits
        model = try MLModel(contentsOf: url, configuration: config)
    }
}
