import CoreML
import Foundation

public enum MarkSpeciesModelError: LocalizedError {
    case missingModel

    public var errorDescription: String? {
        switch self {
        case .missingModel: return "앱 번들에서 \(MarkSpeciesModel.resourceName).mlmodelc를 찾지 못했습니다."
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

    public init() throws {
        guard let url = Bundle(for: MarkSpeciesModel.self).url(forResource: Self.resourceName, withExtension: "mlmodelc") else {
            throw MarkSpeciesModelError.missingModel
        }
        let config = MLModelConfiguration()
        // GPU 로 돌린다 — CPU 를 쓰지 않는다. 임베딩은 서버 카탈로그와 코사인으로 대조하므로 여기가 가장 민감하다.
        // PyTorch 대비 임베딩 코사인 최소(크롭 6장 × 8방향, Mac 측정): cpuOnly 0.9953 · cpuAndNeuralEngine 0.9993
        // · cpuAndGPU 0.9995 · all 0.9996. all 은 CoreML 이 연산 일부를 CPU 로 보낼 수 있어 쓰지 않는다.
        // (CoreML 에 CPU 를 완전히 빼는 설정은 없다 — GPU 가 못 하는 연산만 CPU 로 떨어진다.)
        config.computeUnits = .cpuAndGPU
        model = try MLModel(contentsOf: url, configuration: config)
    }
}
