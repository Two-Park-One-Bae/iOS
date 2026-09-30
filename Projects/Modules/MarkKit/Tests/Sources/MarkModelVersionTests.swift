import XCTest
@testable import MarkKit

/// 요청 `markEmbeddingModel` 로 가는 버전이 실제로 번들한 모델(models.lock)과 같은지 (NM-533).
/// 모델 파일만 바꾸고 버전을 잊으면 서버가 다른 버전의 카탈로그 임베딩과 비교하게 된다.
final class MarkModelVersionTests: XCTestCase {

    func test_모델_버전은_models_lock_의_마크_모델_폴더와_같다() throws {
        // Projects/Modules/MarkKit/Tests/Sources/이 파일 → 레포 루트
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let lock = try String(contentsOf: root.appendingPathComponent("models.lock"), encoding: .utf8)
        let markLine = try XCTUnwrap(lock.split(separator: "\n").first { $0.hasPrefix("models/mark/") })

        XCTAssertTrue(markLine.hasPrefix("models/mark/\(MarkEncoder.modelVersion)/"), String(markLine))
    }
}
