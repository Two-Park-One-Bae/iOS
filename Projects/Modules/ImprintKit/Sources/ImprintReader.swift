import CoreML
import Foundation

/// 한 면의 각인 판독 결과 — 정본 `infer.py` `read_one` 의 반환값.
public struct ImprintReading: Sendable, Equatable {
    /// **확신 글자.** 후보 좁히기(요청의 `imprint`, 출처 MODEL)에 쓰는 값.
    /// 보류·판독 실패는 nil 이다 — 빈 문자열은 "각인 없는 알약만" 조건이라 모델이 내면 안 된다.
    public let sure: String?
    /// 고른 후보의 확신하는 연속 두 글자와 그 확신도(`best_pair`, 소수 넷째 자리 반올림).
    public let pair: String
    public let score: Double
    /// 고른 후보의 전체 판독문.
    public let text: String
}

/// 각인 판독기 — 정본 `models/imprint/20260907-crnn-ep60-s1/infer.py` 를 그대로 옮겼다.
///
/// ```
/// 크롭 → 흑백 → 128 정사각 → 확대 6배율 × 회전 24방향 = 144뷰 → CLAHE → CRNN(배치 24) → CTC 그리디
///      → best_pair 최대 후보 → 확신도 0.949 이상이면 확률 0.95 이상 글자 = 확신 글자
/// ```
///
/// **연산 장치 두 레인에 나눠 돈다(GPU + CPU).** fp32 모델이라 ANE 는 못 쓰고, CPU·GPU 속도가 비슷하다.
/// 알약 하나 = 배치 6개(배율 하나가 24방향 = 배치 하나)이고, 여러 알약의 배치를 두 레인이 먼저 빈 쪽부터
/// 가져간다. 알약 단위로 나누면 알약이 1개일 때 레인 하나가 논다(iPhone 12 실측: 알약 1개 각인 −41%).
/// 레인마다 모델을 따로 연다 — `MLModel` 하나를 여러 스레드가 동시에 부르지 않는다.
public final class ImprintReader: @unchecked Sendable {

    public static let zooms: [Double] = [1.0, 1.2, 1.4, 1.7, 2.0, 2.4]
    public static let rotations = 24
    /// 확신 글자 임계 — 글자 확률(소수 셋째 자리 반올림) 이 이상.
    public static let sureThreshold = 0.95
    /// 채택 조건 — 고른 후보의 best_pair 확신도가 이 미만이면 확신 글자를 내지 않는다(감사셋 정밀도 90% 지점).
    public static let acceptThreshold = 0.949

    static let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    private let lanes: [ImprintReaderModel]

    /// - Parameters:
    ///   - computeUnits: 레인마다 하나. 기본은 GPU(`.all`) + CPU.
    ///   - modelURL: 컴파일된 `.mlmodelc`. nil 이면 번들에서 찾는다.
    public init(computeUnits: [MLComputeUnits] = [.all, .cpuOnly], modelURL: URL? = nil) throws {
        precondition(!computeUnits.isEmpty)
        lanes = try computeUnits.map { try ImprintReaderModel(url: modelURL, computeUnits: $0) }
    }

    /// 여러 면을 한 번에 읽는다. 결과 순서는 입력 순서와 같다.
    public func read(_ faces: [GrayImage]) throws -> [ImprintReading] {
        guard !faces.isEmpty else { return [] }
        let resized = faces.map { PillFacePreprocess.squared($0, size: ImprintReaderModel.inputSize) }

        // 작업 = (면, 배율) = 24방향 = 배치 하나. 면 순서로 줄 세워 앞 알약부터 끝나게 한다.
        let jobs = resized.indices.flatMap { face in Self.zooms.indices.map { (face: face, zoom: $0) } }
        let queue = JobQueue(count: jobs.count)
        let results = ResultStore(count: jobs.count)

        DispatchQueue.concurrentPerform(iterations: lanes.count) { lane in
            let model = lanes[lane].model
            while let index = queue.next(), results.error == nil {
                let job = jobs[index]
                do {
                    let tensors = Self.views(of: resized[job.face], zoom: Self.zooms[job.zoom])
                    let candidates = try Self.infer(model, tensors: tensors, zoom: Self.zooms[job.zoom])
                    results.set(index, candidates)
                } catch {
                    results.fail(error)
                }
            }
        }
        if let error = results.error { throw error }

        return resized.indices.map { face in
            // 배율 순서 → 방향 순서로 이어 붙여야 정본과 같은 후보 순서가 된다(동점이면 앞 후보).
            let candidates = Self.zooms.indices.flatMap { results.value(face * Self.zooms.count + $0) }
            return Self.answer(from: candidates)
        }
    }

    // MARK: - 전처리 (read_image)

    /// 한 배율의 24방향 텐서 — `zoom_frame` → `warpAffine` → CLAHE → [-1, 1]. 방향끼리 독립이라 나눠 만든다.
    static func views(of face128: GrayImage, zoom: Double) -> [[Float]] {
        let size = ImprintReaderModel.inputSize
        let framed = PillFacePreprocess.zoomFrame(face128, zoom: zoom, size: size)
        var tensors = [[Float]](repeating: [], count: rotations)
        tensors.withUnsafeMutableBufferPointer { out in
            let out = out
            DispatchQueue.concurrentPerform(iterations: rotations) { i in
                let angle = Double(i) * 360.0 / Double(rotations)
                let view = PillFacePreprocess.clahe(PillFacePreprocess.rotated(framed, degrees: angle))
                // `to_tensor` — float32 로 /255 → −0.5 → /0.5 (순서까지 같게)
                out[i] = view.pixels.map { (Float($0) / 255 - 0.5) / 0.5 }
            }
        }
        return tensors
    }

    // MARK: - 추론 · 디코드

    struct Candidate {
        let chars: [(Character, Double)]   // 글자별 확률(반올림 전)
        let pair: String
        let score: Double                  // best_pair (소수 넷째 자리 반올림 — 정렬·채택에 쓰는 값)
        var text: String { String(chars.map(\.0)) }
    }

    /// 배치 하나(24뷰) → 뷰마다 CTC 그리디 디코드.
    private static func infer(_ model: MLModel, tensors: [[Float]], zoom: Double) throws -> [Candidate] {
        let batch = ImprintReaderModel.batchSize, side = ImprintReaderModel.inputSize
        precondition(tensors.count == batch)
        let input = try MLMultiArray(shape: [NSNumber(value: batch), 1, NSNumber(value: side), NSNumber(value: side)],
                                     dataType: .float32)
        let pointer = input.dataPointer.bindMemory(to: Float.self, capacity: input.count)
        for (b, tensor) in tensors.enumerated() {
            tensor.withUnsafeBufferPointer { pointer.advanced(by: b * side * side).update(from: $0.baseAddress!, count: side * side) }
        }
        let output = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(multiArray: input)]))
        guard let name = output.featureNames.first, let logits = output.featureValue(for: name)?.multiArrayValue else {
            throw ImprintReaderModelError.missingOutput
        }
        return (0..<batch).map { decode(logits, batchIndex: $0) }
    }

    /// `decode_conf` — 시간축마다 softmax 최대 클래스, 공백(0)·연속 중복을 건너뛴다. 확률은 그 클래스의 softmax.
    static func decode(_ logits: MLMultiArray, batchIndex b: Int) -> Candidate {
        // (T, B, C) — 시간축 먼저
        let steps = logits.shape[0].intValue, classes = logits.shape[2].intValue
        let st = logits.strides[0].intValue, sb = logits.strides[1].intValue, sc = logits.strides[2].intValue
        let p = logits.dataPointer.bindMemory(to: Float.self, capacity: logits.count)

        var chars: [(Character, Double)] = []
        var previous = 0
        for t in 0..<steps {
            let base = t * st + b * sb
            var best = 0
            var maxLogit = -Float.greatestFiniteMagnitude
            for c in 0..<classes where p[base + c * sc] > maxLogit { maxLogit = p[base + c * sc]; best = c }
            var sum = 0.0
            for c in 0..<classes { sum += exp(Double(p[base + c * sc]) - Double(maxLogit)) }
            if best != 0 && best != previous { chars.append((charset[best - 1], 1.0 / sum)) }
            previous = best
        }
        let (pair, score) = bestPair(chars)
        return Candidate(chars: chars, pair: pair, score: round(score, digits: 4))
    }

    /// `best_pair` — 인접 두 글자 확률 중 **낮은 쪽이 가장 높은** 창. 반올림 전 확률로 고른다.
    static func bestPair(_ chars: [(Character, Double)]) -> (String, Double) {
        var best = "", score = 0.0
        guard chars.count >= 2 else { return (best, score) }
        for i in 0..<(chars.count - 1) {
            let s = min(chars[i].1, chars[i + 1].1)
            if s > score { best = String([chars[i].0, chars[i + 1].0]); score = s }
        }
        return (best, score)
    }

    /// `read_one` — 144개 후보 중 확신도 최대(동점이면 앞 후보, 파이썬 안정 정렬)를 고르고 채택 조건을 건다.
    static func answer(from candidates: [Candidate]) -> ImprintReading {
        guard var best = candidates.first else { return ImprintReading(sure: nil, pair: "", score: 0, text: "") }
        for candidate in candidates.dropFirst() where candidate.score > best.score { best = candidate }
        var sure: String?
        if best.score >= acceptThreshold {
            // 정본은 글자 확률을 소수 셋째 자리로 반올림해 둔 값으로 임계를 비교한다(0.9496 → 0.950 통과).
            let text = String(best.chars.filter { round($0.1, digits: 3) >= sureThreshold }.map(\.0))
            sure = text.isEmpty ? nil : text
        }
        return ImprintReading(sure: sure, pair: best.pair, score: best.score, text: best.text)
    }

    /// 파이썬 `round(x, n)` — 짝수 반올림.
    static func round(_ x: Double, digits: Int) -> Double {
        let scale = pow(10.0, Double(digits))
        return (x * scale).rounded(.toNearestOrEven) / scale
    }
}

// MARK: - 레인 공유 상태

/// 레인들이 나눠 갖는 작업 번호표.
private final class JobQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var nextIndex = 0
    private let count: Int
    init(count: Int) { self.count = count }

    func next() -> Int? {
        lock.lock(); defer { lock.unlock() }
        guard nextIndex < count else { return nil }
        defer { nextIndex += 1 }
        return nextIndex
    }
}

/// 작업별 후보. 레인이 제자리에 쓰므로 순서는 작업 번호로 복원된다.
private final class ResultStore: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [[ImprintReader.Candidate]]
    private var firstError: Error?
    init(count: Int) { values = Array(repeating: [], count: count) }

    var error: Error? { lock.lock(); defer { lock.unlock() }; return firstError }
    func value(_ i: Int) -> [ImprintReader.Candidate] { lock.lock(); defer { lock.unlock() }; return values[i] }
    func set(_ i: Int, _ candidates: [ImprintReader.Candidate]) { lock.lock(); values[i] = candidates; lock.unlock() }
    func fail(_ error: Error) { lock.lock(); if firstError == nil { firstError = error }; lock.unlock() }
}
