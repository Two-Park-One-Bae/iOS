import XCTest
@testable import SegmentationKit

/// 라벨 `segModel` 로 가는 버전이 실제로 번들한 모델(models.lock)과 같은지 (NM-568).
/// 모델 파일만 바꾸고 버전을 잊으면 어느 모델이 낸 위치인지 거꾸로 적힌다.
final class SegModelVersionTests: XCTestCase {

    func test_모델_버전은_models_lock_의_분할_모델_폴더와_같다() throws {
        // Projects/Modules/SegmentationKit/Tests/Sources/이 파일 → 레포 루트
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let lock = try String(contentsOf: root.appendingPathComponent("models.lock"), encoding: .utf8)
        let segLine = try XCTUnwrap(lock.split(separator: "\n").first { $0.hasPrefix("models/seg/") })

        XCTAssertTrue(segLine.hasPrefix("models/seg/\(RFDetrSegmentor.modelVersion)/"), String(segLine))
    }
}
