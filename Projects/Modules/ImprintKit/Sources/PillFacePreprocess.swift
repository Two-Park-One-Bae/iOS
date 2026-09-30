import Foundation

/// 각인·마크 모델이 공유하는 기하·전처리 사슬. 참조 코드의 어느 함수인지 함수마다 적어 둔다.
///
/// **모델보다 전처리가 훨씬 민감하다.** 한 곳이라도 어긋나면 예외 없이 조용히 돌고 확신도만 밀린다.
/// 여기 함수를 고칠 때는 정본 파이썬과 화소 대조를 다시 해 차이 0 을 확인한다.
public enum PillFacePreprocess {

    // MARK: - 기하

    /// `_to_square(g, size)` — 정사각 패딩(채움값 = 좌상단 3×3 중앙값) 후 `INTER_AREA` 리사이즈.
    public static func squared(_ g: GrayImage, size: Int) -> GrayImage {
        OpenCV.resizeArea(squarePad(g), width: size, height: size)
    }

    /// `_square_pad(g)` — 리사이즈 없이 정사각 패딩만.
    static func squarePad(_ g: GrayImage) -> GrayImage {
        let side = max(g.width, g.height)
        if g.width == side && g.height == side { return g }
        var corner: [UInt8] = []
        for y in 0..<min(3, g.height) { for x in 0..<min(3, g.width) { corner.append(g[x, y]) } }
        var pad = GrayImage(repeating: OpenCV.median(corner), width: side, height: side)
        let oy = (side - g.height) / 2, ox = (side - g.width) / 2
        for y in 0..<g.height { for x in 0..<g.width { pad[ox + x, oy + y] = g[x, y] } }
        return pad
    }

    /// 각인 `zoom_frame(g, z, size)` — 알약 중심 기준으로 `z` 배 확대해 `size` 정사각으로.
    ///
    /// 참조(`infer.py`)는 크롭을 **먼저 128 로 줄인 뒤** 그 그림에서 확대한다. 원본 크롭에서 확대하면
    /// 확대 뷰가 더 선명해지지만 임계값을 잰 입력과 달라진다 — 참조를 따른다.
    static func zoomFrame(_ g: GrayImage, zoom: Double, size: Int) -> GrayImage {
        if zoom <= 1.0 { return squared(g, size: size) }
        let p = squarePad(g)
        let side = p.width

        var sumY = 0, sumX = 0, count = 0
        for y in 0..<side { for x in 0..<side where p[x, y] < 250 { sumY += y; sumX += x; count += 1 } }
        // `int(ys.mean())` — 평균을 절삭.
        let cy = count > 50 ? Int(Double(sumY) / Double(count)) : side / 2
        let cx = count > 50 ? Int(Double(sumX) / Double(count)) : side / 2
        let half = max(8, Int(Double(side) / zoom / 2))

        // 바깥은 흰색(255)으로 채운다 — `np.pad(constant_values=255)`.
        var cut = GrayImage(repeating: 255, width: half * 2, height: half * 2)
        for y in 0..<(half * 2) {
            let yy = cy - half + y
            guard yy >= 0, yy < side else { continue }
            for x in 0..<(half * 2) {
                let xx = cx - half + x
                guard xx >= 0, xx < side else { continue }
                cut[x, y] = p[xx, yy]
            }
        }
        if min(cut.width, cut.height) < 4 { return squared(g, size: size) }
        return OpenCV.resizeArea(cut, width: size, height: size)
    }

    /// 중심 회전, 바깥은 흰색 — `warpAffine(getRotationMatrix2D((size/2, size/2), degrees, 1))`.
    public static func rotated(_ g: GrayImage, degrees: Double) -> GrayImage {
        OpenCV.rotate(g, degrees: degrees)
    }

    // MARK: - CLAHE 전처리 (apply_prep "clahe" · mark clahe)

    /// 알약 마스크 → 배경을 알약 내부 중앙값으로 메움 → CLAHE(3.0, 8×8) → 마스크 밖은 **흰색**.
    public static func clahe(_ g: GrayImage) -> GrayImage {
        let mask = pillMask(g)
        var hist = [Int](repeating: 0, count: 256)
        var inside = 0
        for i in 0..<g.pixels.count where mask[i] != 0 { hist[Int(g.pixels[i])] += 1; inside += 1 }
        let median = inside == 0 ? 0 : medianFromHistogram(hist, count: inside)

        var filled = g.pixels
        for i in 0..<filled.count where mask[i] == 0 { filled[i] = median }
        var out = OpenCV.clahe(filled, width: g.width, height: g.height)
        for i in 0..<out.count where mask[i] == 0 { out[i] = 255 }
        return GrayImage(pixels: out, width: g.width, height: g.height)
    }

    /// `_mask_pill` — 245 문턱 → 5×5 닫기 → 최대 연결성분 → 구멍 메우기.
    static func pillMask(_ g: GrayImage) -> [UInt8] {
        var m = g.pixels.map { $0 < 245 ? UInt8(1) : UInt8(0) }
        m = OpenCV.morphClose(m, width: g.width, height: g.height)
        m = OpenCV.largestComponent(m, width: g.width, height: g.height)
        return OpenCV.fillHoles(m, width: g.width, height: g.height)
    }

    /// `int(np.median(...))` 를 히스토그램에서. 짝수 개면 가운데 둘의 평균을 절삭.
    private static func medianFromHistogram(_ hist: [Int], count n: Int) -> UInt8 {
        func nth(_ k: Int) -> Int {
            var acc = 0
            for v in 0..<256 {
                acc += hist[v]
                if acc > k { return v }
            }
            return 255
        }
        if n % 2 == 1 { return UInt8(nth(n / 2)) }
        return UInt8((nth(n / 2 - 1) + nth(n / 2)) / 2)
    }
}
