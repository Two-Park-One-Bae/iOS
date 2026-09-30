import CoreML
import Foundation
import ImprintKit

/// 한 면의 마크 결과 — 정본 `mark_species_infer.py` 의 유무·임베딩.
public struct MarkReading: Sendable, Equatable {
    /// 유무 점수 `1 − P(없음)`, 8방향 확률 평균에서. 조건으로 접는 규칙(0.80)은 도메인 `PillMarkRule` 이 갖는다.
    public let presence: Float
    /// 8방향 × 768, 방향 순서(0°, 45°, …) 로 이어 붙인 L2 정규화 임베딩. 서버가 후보 면과 코사인 **최댓값**을 쓴다.
    public let embedding: [Float]
}

/// 마크 인코더 — 정본 `models/mark/20260925-convnext-species/mark_species_infer.py` 를 그대로 옮겼다.
///
/// ```
/// 크롭 → 흑백 → 224 정사각 → 8방향 회전 → CLAHE → 0~1 → ConvNeXt(배치 8) → prob · embedding
/// ```
///
/// 3채널 복제와 ImageNet 정규화는 CoreML 모델 안에 있다. 전처리는 `ImprintKit.PillFacePreprocess` 를 같이 쓴다 —
/// 각인과 같은 OpenCV 재구현이고, 파이썬과 화소 단위로 대조했다.
public final class MarkEncoder: @unchecked Sendable {

    public static let rotations = 8
    static let noneClass = 0

    private let species: MarkSpeciesModel
    private let lock = NSLock()

    public init(modelURL: URL? = nil, computeUnits: MLComputeUnits = .cpuAndNeuralEngine) throws {
        species = try MarkSpeciesModel(url: modelURL, computeUnits: computeUnits)
    }

    public func encode(_ face: GrayImage) throws -> MarkReading {
        let size = MarkSpeciesModel.inputSize
        let base = PillFacePreprocess.squared(face, size: size)

        let input = try MLMultiArray(shape: [NSNumber(value: Self.rotations), 1, NSNumber(value: size), NSNumber(value: size)],
                                     dataType: .float32)
        let pointer = input.dataPointer.bindMemory(to: Float.self, capacity: input.count)
        let plane = size * size
        // 방향끼리 독립이라 나눠 만든다. 각자 제 칸에만 쓴다.
        DispatchQueue.concurrentPerform(iterations: Self.rotations) { k in
            let view = PillFacePreprocess.clahe(PillFacePreprocess.rotated(base, degrees: Double(k) * 360.0 / Double(Self.rotations)))
            let out = pointer.advanced(by: k * plane)
            for i in 0..<plane { out[i] = Float(view.pixels[i]) / 255 }
        }

        // MLModel 하나를 여러 스레드가 동시에 부르지 않는다.
        lock.lock()
        let output = Result { try species.model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["gray": MLFeatureValue(multiArray: input)])) }
        lock.unlock()
        let features = try output.get()
        guard let prob = features.featureValue(for: "prob")?.multiArrayValue,
              let embedding = features.featureValue(for: "embedding")?.multiArrayValue else {
            throw MarkSpeciesModelError.missingOutput
        }

        // 확률은 8방향 평균 — `lo.softmax(-1).mean(0)`. fp16 출력일 수 있어 원소 접근으로 읽는다.
        var none: Float = 0
        for r in 0..<Self.rotations { none += prob[[NSNumber(value: r), NSNumber(value: Self.noneClass)]].floatValue }
        none /= Float(Self.rotations)

        let dimension = embedding.shape[1].intValue
        var vectors = [Float](repeating: 0, count: Self.rotations * dimension)
        for r in 0..<Self.rotations {
            for d in 0..<dimension {
                vectors[r * dimension + d] = embedding[[NSNumber(value: r), NSNumber(value: d)]].floatValue
            }
        }
        return MarkReading(presence: 1 - none, embedding: vectors)
    }
}
