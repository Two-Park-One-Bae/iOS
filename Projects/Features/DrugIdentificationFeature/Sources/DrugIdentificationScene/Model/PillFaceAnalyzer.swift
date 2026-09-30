import CoreGraphics
import Foundation
import ImprintKit
import MarkKit

/// 알약 한 면의 온디바이스 모델값 — 수정 화면 앞면 각인·마크의 초기값과 후보 재정렬 임베딩(NM-459 · NM-512).
struct PillFaceModelResult: Equatable {
    /// 각인 확신 글자. 보류·판독 실패면 nil — 수정 화면은 `전체` 로 시작한다.
    let imprint: String?
    /// 마크 유무 점수 `1 − P(없음)`. 조건으로 접는 규칙(각인 있음 0.80 · 없음 0.60)은 도메인 `PillMarkRule` 이 갖는다.
    let markScore: Float
    /// 8방향 × 768 임베딩 — 요청 `markEmbedding` 으로 서버에 간다.
    let embedding: [Float]
}

/// 각인(ImprintKit)·마크(MarkKit) 모델을 한 번 열어 두고 크롭마다 돌린다.
///
/// **각인과 마크는 동시에 돈다.** 쓰는 장치가 달라서다 — 각인은 GPU·CPU 두 레인(fp32 라 ANE 불가),
/// 마크는 Neural Engine(fp16). iPhone 12 · 번들 사진(알약 6개) 실측: 순차 판독 9.2초 → 5.4초.
///
/// **모델은 앱 수명 동안 한 벌만 연다.** 마크는 ANE 로 처음 열 때 컴파일이 수 초 걸리므로
/// 촬영 화면이 뜰 때 `prewarm()` 으로 미리 연다. 스캔마다 열면 그 시간이 매번 로딩에 붙는다.
final class PillFaceAnalyzer: @unchecked Sendable {

    static let shared = PillFaceAnalyzer()

    private let loadLock = NSLock()
    private var models: (reader: ImprintReader, encoder: MarkEncoder)?
    /// 스캔 둘이 겹치면 차례로 돈다 — 레인마다 모델이 하나라 동시에 부르지 않는다.
    private let runLock = NSLock()

    /// 모델을 백그라운드에서 미리 연다. 이미 열려 있으면 아무 일도 하지 않는다.
    func prewarm() {
        DispatchQueue.global(qos: .utility).async { [self] in _ = try? loadedModels() }
    }

    private func loadedModels() throws -> (reader: ImprintReader, encoder: MarkEncoder) {
        loadLock.lock()
        defer { loadLock.unlock() }
        if let models { return models }
        let loaded = (reader: try ImprintReader(), encoder: try MarkEncoder())
        models = loaded
        return loaded
    }

    /// 크롭마다 모델값. 크롭이 없거나 흑백으로 못 바꾼 알약은 nil. **호출한 스레드를 막는다** — 메인에서 부르지 않는다.
    func analyze(_ crops: [CGImage?]) throws -> [PillFaceModelResult?] {
        let models = try loadedModels()
        runLock.lock()
        defer { runLock.unlock() }

        let faces = crops.map { $0.flatMap(GrayImage.init(pillCrop:)) }
        let present = faces.indices.filter { faces[$0] != nil }
        let grays = present.map { faces[$0]! }
        guard !grays.isEmpty else { return crops.map { _ in nil } }

        // 마크(ANE)는 다른 큐에서, 각인(GPU·CPU 레인)은 이 스레드에서 — 끝나면 합류한다.
        let group = DispatchGroup()
        let marks = ResultBox<[MarkReading]>()
        DispatchQueue.global(qos: .userInitiated).async(group: group) {
            marks.result = Result { try grays.map { try models.encoder.encode($0) } }
        }
        let imprints = Result { try models.reader.read(grays) }
        group.wait()
        let readings = try imprints.get(), markReadings = try marks.result.get()

        var results = [PillFaceModelResult?](repeating: nil, count: crops.count)
        for (k, index) in present.enumerated() {
            results[index] = PillFaceModelResult(
                imprint: readings[k].sure,
                markScore: markReadings[k].presence,
                embedding: markReadings[k].embedding
            )
        }
        return results
    }
}

/// 다른 큐가 채운 결과를 `DispatchGroup.wait()` 뒤에 읽는다 — 기다림이 순서를 보장한다.
private final class ResultBox<Value>: @unchecked Sendable {
    var result: Result<Value, Error> = .failure(CancellationError())
}
