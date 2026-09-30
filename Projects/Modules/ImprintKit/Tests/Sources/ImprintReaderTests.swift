import XCTest
@testable import ImprintKit

/// 각인 판독 답 규칙 (NM-459) — 정본 `models/imprint/20260907-crnn-ep60-s1/infer.py` `read_one`.
final class ImprintReaderTests: XCTestCase {

    // MARK: - 답 규칙

    func test_확신도가_채택_임계_미만이면_확신_글자를_내지_않는다() {
        let candidate = ImprintReader.Candidate(chars: [("A", 0.99), ("X", 0.948)], pair: "AX", score: 0.948)
        XCTAssertNil(ImprintReader.answer(from: [candidate]).sure)
    }

    func test_글자_확률은_셋째_자리로_반올림한_뒤_임계를_비교한다() {
        // 0.9496 → 0.950 이라 통과, 0.9494 → 0.949 라 탈락 — 정본이 반올림해 둔 값으로 비교한다.
        let candidate = ImprintReader.Candidate(chars: [("A", 0.99), ("L", 0.9494), ("X", 0.9496)], pair: "AL", score: 0.9494)
        XCTAssertEqual(ImprintReader.answer(from: [candidate]).sure, "AX")
    }

    func test_확신도가_같으면_앞_후보를_고른다() {
        let first = ImprintReader.Candidate(chars: [("A", 0.99), ("X", 0.99)], pair: "AX", score: 0.99)
        let second = ImprintReader.Candidate(chars: [("B", 0.99), ("Y", 0.99)], pair: "BY", score: 0.99)
        XCTAssertEqual(ImprintReader.answer(from: [first, second]).pair, "AX")
    }

    func test_판독_실패는_빈_문자열이_아니라_nil이다() {
        XCTAssertNil(ImprintReader.answer(from: []).sure)
        let silent = ImprintReader.Candidate(chars: [], pair: "", score: 0)
        XCTAssertNil(ImprintReader.answer(from: [silent]).sure)
    }

    // MARK: - 레인

    /// 배치를 레인 여럿에 나눠도 결과가 같아야 한다 — 레인은 속도만 바꾼다.
    func test_레인_하나와_둘의_결과가_같다() throws {
        let faces = [Self.syntheticPill(width: 180, height: 120), Self.syntheticPill(width: 140, height: 150)]
        let one = try ImprintReader(computeUnits: [.cpuOnly]).read(faces)
        let two = try ImprintReader(computeUnits: [.cpuOnly, .cpuOnly]).read(faces)
        XCTAssertEqual(one, two)
    }

    /// 흰 배경 위 회색 타원 알약에 어두운 획 몇 개 — 모델을 끝까지 돌리기 위한 입력.
    private static func syntheticPill(width: Int, height: Int) -> GrayImage {
        var pixels = [UInt8](repeating: 255, count: width * height)
        let cx = Double(width) / 2, cy = Double(height) / 2
        let rx = Double(width) * 0.45, ry = Double(height) * 0.4
        for y in 0..<height {
            for x in 0..<width {
                let d = pow((Double(x) - cx) / rx, 2) + pow((Double(y) - cy) / ry, 2)
                guard d <= 1 else { continue }
                let stroke = (x / 6) % 4 == 0 && abs(Double(y) - cy) < ry * 0.5
                pixels[y * width + x] = stroke ? 70 : 190
            }
        }
        return GrayImage(pixels: pixels, width: width, height: height)
    }
}
