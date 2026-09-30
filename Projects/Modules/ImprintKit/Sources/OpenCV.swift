import Foundation

/// 참조 코드(파이썬 OpenCV 4.11)와 **비트 단위로 같은 결과**를 내는 재구현.
///
/// 각인·마크 모델의 임계값(각인 0.95·0.949, 마크 0.80)은 OpenCV 로 전처리한 입력에서 잰 눈금이다.
/// "비슷한 보간"으로는 화소가 ±1 씩 어긋나고, 그만큼 확신도가 밀려 눈금이 안 맞는다.
/// 그래서 OpenCV 내부 구현(고정소수점·반올림 규칙까지)을 따르고, 정본 파이썬과 대조해 차이 0 을 확인했다
/// (2026-09-30 · OpenCV 4.11 arm64 · 크롭 25장의 흑백 · 각인 144뷰 · 마크 8뷰).
enum OpenCV {

    // MARK: - cvtColor(BGR2GRAY)

    /// `cv2.COLOR_BGR2GRAY` — 계수 0.114·0.587·0.299 를 **15비트** 고정소수점으로(3735 · 19235 · 9798).
    ///
    /// OpenCV 4.x 는 흑백 변환을 15비트로 한다. 흔히 알려진 14비트(1868 · 9617 · 4899)로 하면 색 0.27% 에서
    /// 1 씩 틀린다(무작위 400만 색 대조, 15비트는 0).
    @inline(__always)
    static func bgrToGray(b: UInt8, g: UInt8, r: UInt8) -> UInt8 {
        let blue = Int(b) * 3735
        let green = Int(g) * 19235
        let red = Int(r) * 9798
        return UInt8((blue + green + red + 16384) >> 15)
    }

    // MARK: - np.median

    /// `int(np.median(a))` — 짝수 개면 가운데 둘의 평균을 **절삭**한다.
    static func median(_ values: [UInt8]) -> UInt8 {
        guard !values.isEmpty else { return 0 }
        let s = values.sorted()
        let n = s.count
        if n % 2 == 1 { return s[n / 2] }
        return UInt8((Int(s[n / 2 - 1]) + Int(s[n / 2])) / 2)
    }

    // MARK: - resize(INTER_AREA)

    /// `cv2.resize(src, (w, h), interpolation=cv2.INTER_AREA)`.
    ///
    /// OpenCV 는 배율에 따라 세 경로로 갈린다 — 셋 다 따로 맞췄다.
    /// - 축소 · 정수배: 블록 평균. 2배는 SIMD 식 `(합+2)>>2`, 그 밖은 `rint(합 × (1/면적))` (반올림 규칙이 다르다)
    /// - 축소 · 그 밖: 면적 가중 표(`computeResizeAreaTab`) + float 누적
    /// - 확대: `INTER_LINEAR` 에 면적 계수 · 11비트 고정소수점, 세로는 SIMD 식
    static func resizeArea(_ src: GrayImage, width dw: Int, height dh: Int) -> GrayImage {
        let sw = src.width, sh = src.height
        if sw == dw && sh == dh { return src }
        let scaleX = Double(sw) / Double(dw), scaleY = Double(sh) / Double(dh)
        if scaleX >= 1 && scaleY >= 1 {
            let ix = Int(scaleX.rounded(.toNearestOrEven)), iy = Int(scaleY.rounded(.toNearestOrEven))
            if abs(scaleX - Double(ix)) < Double.ulpOfOne && abs(scaleY - Double(iy)) < Double.ulpOfOne {
                return resizeAreaFast(src, width: dw, height: dh, kx: ix, ky: iy)
            }
            return resizeAreaGeneral(src, width: dw, height: dh)
        }
        return resizeAreaUp(src, width: dw, height: dh)
    }

    private static func resizeAreaFast(_ src: GrayImage, width dw: Int, height dh: Int, kx: Int, ky: Int) -> GrayImage {
        var out = GrayImage(repeating: 0, width: dw, height: dh)
        let area = kx * ky
        let inverse = Float(1.0 / Double(area))
        src.pixels.withUnsafeBufferPointer { s in
            for dy in 0..<dh {
                for dx in 0..<dw {
                    var sum = 0
                    for y in 0..<ky {
                        let row = (dy * ky + y) * src.width + dx * kx
                        for x in 0..<kx { sum += Int(s[row + x]) }
                    }
                    let value = (kx == 2 && ky == 2)
                        ? (sum + 2) >> 2
                        : Int((Float(sum) * inverse).rounded(.toNearestOrEven))
                    out[dx, dy] = UInt8(max(0, min(255, value)))
                }
            }
        }
        return out
    }

    private struct AreaTab {
        let dst: Int
        let src: Int
        let alpha: Float
    }

    /// OpenCV `computeResizeAreaTab`.
    private static func areaTab(source: Int, destination: Int, scale: Double) -> [AreaTab] {
        var tab: [AreaTab] = []
        for d in 0..<destination {
            let fs1 = Double(d) * scale
            let fs2 = fs1 + scale
            let cellWidth = min(scale, Double(source) - fs1)
            var s1 = Int(fs1.rounded(.up))
            var s2 = Int(fs2.rounded(.down))
            s2 = min(s2, source - 1)
            s1 = min(s1, s2)
            if Double(s1) - fs1 > 1e-3 {
                tab.append(AreaTab(dst: d, src: s1 - 1, alpha: Float((Double(s1) - fs1) / cellWidth)))
            }
            if s1 < s2 {
                for s in s1..<s2 { tab.append(AreaTab(dst: d, src: s, alpha: Float(1.0 / cellWidth))) }
            }
            if fs2 - Double(s2) > 1e-3 {
                tab.append(AreaTab(dst: d, src: s2, alpha: Float(min(min(fs2 - Double(s2), 1.0), cellWidth) / cellWidth)))
            }
        }
        return tab
    }

    /// OpenCV `ResizeArea_Invoker` — 가로 가중합을 행마다 float 로 만든 뒤 세로로 누적한다(순서까지 같게).
    private static func resizeAreaGeneral(_ src: GrayImage, width dw: Int, height dh: Int) -> GrayImage {
        let xTab = areaTab(source: src.width, destination: dw, scale: Double(src.width) / Double(dw))
        let yTab = areaTab(source: src.height, destination: dh, scale: Double(src.height) / Double(dh))
        var out = GrayImage(repeating: 0, width: dw, height: dh)
        var buffer = [Float](repeating: 0, count: dw)
        var sum = [Float](repeating: 0, count: dw)
        var previous = yTab[0].dst

        func flush(_ row: Int) {
            for x in 0..<dw {
                out[x, row] = UInt8(max(0, min(255, Int(sum[x].rounded(.toNearestOrEven)))))
            }
        }

        src.pixels.withUnsafeBufferPointer { s in
            for entry in yTab {
                for x in 0..<dw { buffer[x] = 0 }
                let row = entry.src * src.width
                for t in xTab { buffer[t.dst] += Float(s[row + t.src]) * t.alpha }
                if entry.dst != previous {
                    flush(previous)
                    for x in 0..<dw { sum[x] = entry.alpha * buffer[x] }
                    previous = entry.dst
                } else {
                    for x in 0..<dw { sum[x] += entry.alpha * buffer[x] }
                }
            }
        }
        flush(previous)
        return out
    }

    /// INTER_AREA 확대 — OpenCV 가 `INTER_LINEAR` 로 바꾸되 계수만 면적식으로 잡는다(`area_mode`).
    private static func resizeAreaUp(_ src: GrayImage, width dw: Int, height dh: Int) -> GrayImage {
        let one = 2048  // INTER_RESIZE_COEF_SCALE

        func coefficients(source: Int, destination: Int) -> (index: [Int], a0: [Int], a1: [Int], max: Int) {
            let scale = Double(source) / Double(destination)
            let inverse = Double(destination) / Double(source)
            var index = [Int](), a0 = [Int](), a1 = [Int]()
            var limit = destination
            for d in 0..<destination {
                var s = Int((Double(d) * scale).rounded(.down))
                var f = Float(Double(d + 1) - Double(s + 1) * inverse)
                f = f <= 0 ? 0 : f - f.rounded(.down)
                if s < 0 { f = 0; s = 0 }
                if s + 1 >= source {
                    limit = min(limit, d)
                    if s >= source - 1 { f = 0; s = source - 1 }
                }
                index.append(s)
                a0.append(Int(((1 - f) * Float(one)).rounded(.toNearestOrEven)))
                a1.append(Int((f * Float(one)).rounded(.toNearestOrEven)))
            }
            return (index, a0, a1, limit)
        }

        let xc = coefficients(source: src.width, destination: dw)
        let yc = coefficients(source: src.height, destination: dh)

        // 가로: 원본 행마다 정수 가중합(×2048).
        var horizontal = [Int](repeating: 0, count: src.height * dw)
        src.pixels.withUnsafeBufferPointer { s in
            for y in 0..<src.height {
                let row = y * src.width
                for d in 0..<dw {
                    let sx = xc.index[d]
                    horizontal[y * dw + d] = d < xc.max
                        ? Int(s[row + sx]) * xc.a0[d] + Int(s[row + min(sx + 1, src.width - 1)]) * xc.a1[d]
                        : Int(s[row + sx]) * one
                }
            }
        }

        // 세로: 8칸 단위는 SIMD 식(`VResizeLinearVec_32s8u`), 나머지는 스칼라 식.
        var out = GrayImage(repeating: 0, width: dw, height: dh)
        let simdWidth = dw / 8 * 8
        for d in 0..<dh {
            let r0 = yc.index[d] * dw
            let r1 = min(yc.index[d] + 1, src.height - 1) * dw
            let b0 = yc.a0[d], b1 = yc.a1[d]
            for x in 0..<dw {
                let s0 = horizontal[r0 + x], s1 = horizontal[r1 + x]
                let value = x < simdWidth
                    ? ((((s0 >> 4) * b0) >> 16) + (((s1 >> 4) * b1) >> 16) + 2) >> 2
                    : (s0 * b0 + s1 * b1 + (1 << 21)) >> 22
                out[x, d] = UInt8(max(0, min(255, value)))
            }
        }
        return out
    }

    // MARK: - warpAffine(getRotationMatrix2D)

    /// `cv2.warpAffine(src, cv2.getRotationMatrix2D((w/2, h/2), degrees, 1.0), (w, h), borderValue=255)`.
    ///
    /// 쌍선형 보간을 **OpenCV 고정소수점**으로 한다 — 좌표 1/32 화소(INTER_BITS 5), 역행렬 좌표는 10비트
    /// (AB_BITS), 가중치 15비트. 실수 쌍선형으로 돌리면 화소가 ±1 씩 어긋난다.
    static func rotate(_ src: GrayImage, degrees: Double, border: UInt8 = 255) -> GrayImage {
        let w = src.width, h = src.height
        let cx = Double(w) / 2, cy = Double(h) / 2

        // getRotationMatrix2D
        let angle = degrees * Double.pi / 180
        let alpha = cos(angle), beta = sin(angle)
        var m = [alpha, beta, (1 - alpha) * cx - beta * cy,
                 -beta, alpha, beta * cx + (1 - alpha) * cy]

        // invertAffineTransform (warpAffine 이 WARP_INVERSE_MAP 없이 부르면 안에서 뒤집는다)
        var det = m[0] * m[4] - m[1] * m[3]
        det = det != 0 ? 1.0 / det : 0
        let a11 = m[4] * det, a22 = m[0] * det
        m[0] = a11; m[1] *= -det; m[3] *= -det; m[4] = a22
        let b1 = -m[0] * m[2] - m[1] * m[5]
        let b2 = -m[3] * m[2] - m[4] * m[5]
        m[2] = b1; m[5] = b2

        let abScale = 1024.0          // 1 << AB_BITS
        let roundDelta = 1024 / 32 / 2
        @inline(__always) func cvRound(_ v: Double) -> Int { Int(v.rounded(.toNearestOrEven)) }
        let aDelta = (0..<w).map { cvRound(m[0] * Double($0) * abScale) }
        let bDelta = (0..<w).map { cvRound(m[3] * Double($0) * abScale) }

        var out = GrayImage(repeating: border, width: w, height: h)
        let borderValue = Int(border)
        src.pixels.withUnsafeBufferPointer { s in
            @inline(__always) func at(_ x: Int, _ y: Int) -> Int {
                (x >= 0 && y >= 0 && x < w && y < h) ? Int(s[y * w + x]) : borderValue
            }
            for y in 0..<h {
                let x0 = cvRound((m[1] * Double(y) + m[2]) * abScale) + roundDelta
                let y0 = cvRound((m[4] * Double(y) + m[5]) * abScale) + roundDelta
                for x in 0..<w {
                    let fxAll = (x0 + aDelta[x]) >> 5
                    let fyAll = (y0 + bDelta[x]) >> 5
                    let sx = fxAll >> 5, sy = fyAll >> 5
                    let fx = fxAll & 31, fy = fyAll & 31
                    // 가중치 = (32−f)·(32−g) 등 × 32 → 합 32768(15비트)
                    let w00 = (32 - fx) * (32 - fy) * 32, w10 = fx * (32 - fy) * 32
                    let w01 = (32 - fx) * fy * 32, w11 = fx * fy * 32
                    let sum = at(sx, sy) * w00 + at(sx + 1, sy) * w10 + at(sx, sy + 1) * w01 + at(sx + 1, sy + 1) * w11
                    out[x, y] = UInt8(max(0, min(255, (sum + (1 << 14)) >> 15)))
                }
            }
        }
        return out
    }

    // MARK: - 알약 마스크 (_mask_pill)

    /// `morphologyEx(MORPH_CLOSE, 5×5)` — 팽창 후 침식.
    ///
    /// **이미지 바깥은 조건에서 뺀다** — OpenCV 기본 테두리(`morphologyDefaultBorderValue`)는 팽창엔 최솟값,
    /// 침식엔 최댓값이라 바깥이 결과를 바꾸지 못한다. 바깥을 0 으로 보고 침식하면 알약이 크롭 가장자리에
    /// 닿는 곳(세그 크롭은 늘 닿는다)이 깎인다.
    static func morphClose(_ mask: [UInt8], width w: Int, height h: Int, kernel k: Int = 5) -> [UInt8] {
        erodeOrDilate(erodeOrDilate(mask, width: w, height: h, kernel: k, dilate: true),
                      width: w, height: h, kernel: k, dilate: false)
    }

    /// 정사각 구조요소는 행 1차원 + 열 1차원으로 나눠도 결과가 같다.
    private static func erodeOrDilate(_ mask: [UInt8], width w: Int, height h: Int, kernel k: Int, dilate: Bool) -> [UInt8] {
        let r = k / 2
        var rows = [UInt8](repeating: 0, count: w * h)
        var out = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                var v: UInt8 = dilate ? 0 : 1
                for dx in -r...r {
                    let xx = x + dx
                    guard xx >= 0, xx < w else { continue }
                    let s = mask[y * w + xx]
                    if dilate { if s != 0 { v = 1; break } } else if s == 0 { v = 0; break }
                }
                rows[y * w + x] = v
            }
        }
        for y in 0..<h {
            for x in 0..<w {
                var v: UInt8 = dilate ? 0 : 1
                for dy in -r...r {
                    let yy = y + dy
                    guard yy >= 0, yy < h else { continue }
                    let s = rows[yy * w + x]
                    if dilate { if s != 0 { v = 1; break } } else if s == 0 { v = 0; break }
                }
                out[y * w + x] = v
            }
        }
        return out
    }

    /// `connectedComponentsWithStats(connectivity 8)` 에서 **면적 최대** 성분만 남긴다.
    /// 성분이 하나도 없으면 그대로 돌려준다(파이썬 `if n > 1`).
    static func largestComponent(_ mask: [UInt8], width w: Int, height h: Int) -> [UInt8] {
        var label = [Int32](repeating: 0, count: w * h)
        var areas: [Int] = [0]
        var next: Int32 = 1
        var stack: [Int] = []
        for start in 0..<(w * h) where mask[start] != 0 && label[start] == 0 {
            var area = 0
            stack.append(start)
            label[start] = next
            while let p = stack.popLast() {
                area += 1
                let py = p / w, px = p % w
                for dy in -1...1 {
                    let yy = py + dy
                    guard yy >= 0, yy < h else { continue }
                    for dx in -1...1 {
                        let xx = px + dx
                        guard xx >= 0, xx < w else { continue }
                        let q = yy * w + xx
                        if mask[q] != 0 && label[q] == 0 { label[q] = next; stack.append(q) }
                    }
                }
            }
            areas.append(area)
            next += 1
        }
        guard areas.count > 1 else { return mask }
        var best = 1
        for i in 1..<areas.count where areas[i] > areas[best] { best = i }
        return label.map { $0 == Int32(best) ? 1 : 0 }
    }

    /// `floodFill(ff, (0, 0), 1)` 후 `m | (1 − ff)` — 바깥(0,0)에서 4-이웃으로 닿지 않는 0 을 메운다.
    static func fillHoles(_ mask: [UInt8], width w: Int, height h: Int) -> [UInt8] {
        var outside = [Bool](repeating: false, count: w * h)
        var stack: [Int] = []
        if mask[0] == 0 { outside[0] = true; stack.append(0) }
        while let p = stack.popLast() {
            let py = p / w, px = p % w
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let xx = px + dx, yy = py + dy
                guard xx >= 0, xx < w, yy >= 0, yy < h else { continue }
                let q = yy * w + xx
                if !outside[q] && mask[q] == 0 { outside[q] = true; stack.append(q) }
            }
        }
        var out = mask
        for i in 0..<out.count where !outside[i] { out[i] = 1 }
        return out
    }

    // MARK: - CLAHE (clipLimit 3.0 · 8×8)

    /// `cv2.createCLAHE(clipLimit, (tiles, tiles)).apply(src)` — OpenCV 구현을 그대로 따른다.
    ///
    /// 1. 타일이 나누어떨어지지 않으면 `BORDER_REFLECT_101` 로 늘려 맞춘다
    /// 2. 타일 히스토그램 → clipLimit 로 자르고 잘라낸 양을 **OpenCV 와 같은 걸음으로** 재분배
    /// 3. 누적합 × (255/타일 화소 수) → LUT (`saturate_cast` = 짝수 반올림)
    /// 4. 이웃 타일 LUT 4개를 쌍선형 보간
    ///
    /// 3·4 는 OpenCV 처럼 **float(32비트)** 로 계산한다. double 로 하면 타일이 16×16(각인 128)일 땐 같지만
    /// 28×28(마크 224)에선 255/784 · 1/28 이 float 와 달라 화소 0.2% 가 ±1 어긋났다.
    ///
    /// 보간은 **FMA(곱셈·덧셈 한 번 반올림)** 로 한다 — arm64 용 cv2 는 clang 이 이 식들을 FMA 로 합쳐
    /// 빌드돼 있다(`-ffp-contract=on`). 합치지 않으면 마크 224 에서 화소 0.1% 가 ±1 다르다. 단 FMA 가 없는
    /// x86 기본 빌드의 cv2 는 합치지 않은 식으로 계산하므로, **참조 코드끼리도 플랫폼에 따라 이만큼 다르다.**
    /// 기기와 같은 arm64 결과에 맞췄다.
    static func clahe(_ src: [UInt8], width: Int, height: Int, clipLimit: Double = 3.0, tiles: Int = 8) -> [UInt8] {
        let tileW = (width + tiles - 1) / tiles
        let tileH = (height + tiles - 1) / tiles
        let paddedW = tileW * tiles, paddedH = tileH * tiles
        let padded = (paddedW == width && paddedH == height)
            ? src
            : reflect101(src, width: width, height: height, newWidth: paddedW, newHeight: paddedH)

        let tileArea = tileW * tileH
        // `static_cast<int>` — 절삭이다. 반올림하면 타일 클리핑이 통째로 달라진다.
        let limit = max(Int(clipLimit * Double(tileArea) / 256.0), 1)
        let lutScale = Float(255) / Float(tileArea)
        var luts = [UInt8](repeating: 0, count: tiles * tiles * 256)

        for ty in 0..<tiles {
            for tx in 0..<tiles {
                var hist = [Int](repeating: 0, count: 256)
                for y in (ty * tileH)..<((ty + 1) * tileH) {
                    let row = y * paddedW
                    for x in (tx * tileW)..<((tx + 1) * tileW) { hist[Int(padded[row + x])] += 1 }
                }
                if clipLimit > 0 {
                    var clipped = 0
                    for i in 0..<256 where hist[i] > limit {
                        clipped += hist[i] - limit
                        hist[i] = limit
                    }
                    let batch = clipped / 256
                    var residual = clipped - batch * 256
                    if batch > 0 { for i in 0..<256 { hist[i] += batch } }
                    if residual > 0 {
                        let step = max(1, 256 / residual)
                        var i = 0
                        while i < 256 && residual > 0 {
                            hist[i] += 1
                            residual -= 1
                            i += step
                        }
                    }
                }
                var sum = 0
                let base = (ty * tiles + tx) * 256
                for i in 0..<256 {
                    sum += hist[i]
                    let v = (Float(sum) * lutScale).rounded(.toNearestOrEven)
                    luts[base + i] = UInt8(max(0, min(255, v)))
                }
            }
        }

        // OpenCV `CLAHE_Interpolation_Body` — 좌표·가중치·보간 전부 float.
        var out = [UInt8](repeating: 0, count: width * height)
        let invTileW = 1 / Float(tileW), invTileH = 1 / Float(tileH)
        var xLeft = [Int](repeating: 0, count: width), xRight = [Int](repeating: 0, count: width)
        var xa = [Float](repeating: 0, count: width), xa1 = [Float](repeating: 0, count: width)
        for x in 0..<width {
            let txf = Float(-0.5).addingProduct(Float(x), invTileW)
            let tx1 = Int(txf.rounded(.down))
            xa[x] = txf - Float(tx1)
            xa1[x] = 1 - xa[x]
            xLeft[x] = max(tx1, 0)
            xRight[x] = min(tx1 + 1, tiles - 1)
        }
        for y in 0..<height {
            let tyf = Float(-0.5).addingProduct(Float(y), invTileH)
            let ty1Raw = Int(tyf.rounded(.down))
            let ya = tyf - Float(ty1Raw), ya1 = 1 - ya
            let ty1 = max(ty1Raw, 0), ty2 = min(ty1Raw + 1, tiles - 1)
            for x in 0..<width {
                let v = Int(src[y * width + x])
                // fma(a, xa1, b·xa) · fma(top, ya1, bottom·ya)
                let a = Float(luts[(ty1 * tiles + xLeft[x]) * 256 + v])
                let b = Float(luts[(ty1 * tiles + xRight[x]) * 256 + v])
                let c = Float(luts[(ty2 * tiles + xLeft[x]) * 256 + v])
                let d = Float(luts[(ty2 * tiles + xRight[x]) * 256 + v])
                let top = (b * xa[x]).addingProduct(a, xa1[x])
                let bottom = (d * xa[x]).addingProduct(c, xa1[x])
                let r = (bottom * ya).addingProduct(top, ya1).rounded(.toNearestOrEven)
                out[y * width + x] = UInt8(max(0, min(255, r)))
            }
        }
        return out
    }

    /// `BORDER_REFLECT_101` — 가장자리 화소를 축으로 접는다(가장자리 자신은 겹치지 않는다).
    private static func reflect101(_ src: [UInt8], width: Int, height: Int, newWidth: Int, newHeight: Int) -> [UInt8] {
        func fold(_ i: Int, _ n: Int) -> Int {
            if n == 1 { return 0 }
            var v = i
            while v < 0 || v >= n {
                if v < 0 { v = -v }
                if v >= n { v = 2 * (n - 1) - v }
            }
            return v
        }
        var out = [UInt8](repeating: 0, count: newWidth * newHeight)
        for y in 0..<newHeight {
            let sy = fold(y, height)
            for x in 0..<newWidth { out[y * newWidth + x] = src[sy * width + fold(x, width)] }
        }
        return out
    }
}
