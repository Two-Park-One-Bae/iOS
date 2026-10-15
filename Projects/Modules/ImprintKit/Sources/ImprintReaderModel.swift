import CoreML
import Foundation

public enum ImprintReaderModelError: LocalizedError {
    case missingModel
    case missingOutput

    public var errorDescription: String? {
        switch self {
        case .missingModel: return "앱 번들에서 \(ImprintReaderModel.resourceName).mlmodelc를 찾지 못했습니다."
        case .missingOutput: return "각인 모델 출력(logits)을 읽지 못했습니다."
        }
    }
}

/// 각인 판독기(CRNN, ep60 시드 1) CoreML 모델 (NM-459).
///
/// 입력 `image` [24,1,128,128] — CLAHE 를 끝낸 흑백. 출력 `logits` [32,24,37] (시간축 · 배치 · 클래스).
/// 배치 24 고정: 가변 shape 은 ANE 를 잘 못 탄다. (배율·방향) 조합을 묶어 한 번에 넘긴다.
///
/// **혼합 정밀도(keep-matmul)** — matmul 6개(TPS 2 · attention 4)만 fp32, 나머지는 fp16 이라 ANE 를 탄다.
/// 전부 fp16 이면 확신 글자가 절반 가까이 바뀐다(감사셋 채택 238 → 137면). matmul 을 남기면 fp32 와 같은 수준.
/// 규격·전처리는 ML 레포 `models/imprint/20260907-crnn-ep60-s1/INFO.md`.
public final class ImprintReaderModel {
    static let resourceName = "Reader_s1_b24_keepmatmul"
    public static let batchSize = 24
    public static let inputSize = 128

    public let model: MLModel

    /// `.cpuAndNeuralEngine` 이면 fp16 연산은 ANE, fp32 matmul · LSTM 은 CPU 로 돈다. **GPU 는 쓰지 않는다** —
    /// GPU(MPSGraph) 첫 그래프 특수화에서 앱이 죽는 크래시를 피한다(2.0.1, iOS 27 · A19).
    /// `ImprintReader` 가 레인마다 하나씩 연다.
    /// - Parameter url: 컴파일된 `.mlmodelc`. nil 이면 이 프레임워크 번들에서 찾는다(대조 도구가 경로를 준다).
    public init(url: URL? = nil, computeUnits: MLComputeUnits = .all) throws {
        guard let url = url ?? Bundle(for: ImprintReaderModel.self).url(forResource: Self.resourceName, withExtension: "mlmodelc") else {
            throw ImprintReaderModelError.missingModel
        }
        let config = MLModelConfiguration()
        config.computeUnits = computeUnits
        model = try MLModel(contentsOf: url, configuration: config)
    }
}
