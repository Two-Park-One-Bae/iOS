import CoreGraphics
import Foundation

/// 8비트 흑백 한 장 — 파이썬 `np.ndarray(H, W) uint8` 에 대응한다.
///
/// 각인·마크 모델은 둘 다 흑백으로 학습했다. 전처리는 `PillFacePreprocess` 가 맡는다.
public struct GrayImage: Sendable, Equatable {
    public var pixels: [UInt8]
    public let width: Int
    public let height: Int

    public init(pixels: [UInt8], width: Int, height: Int) {
        precondition(pixels.count == width * height, "화소 수가 \(pixels.count), 기대값 \(width * height)")
        self.pixels = pixels
        self.width = width
        self.height = height
    }

    init(repeating value: UInt8, width: Int, height: Int) {
        self.init(pixels: [UInt8](repeating: value, count: width * height), width: width, height: height)
    }

    @inline(__always) subscript(x: Int, y: Int) -> UInt8 {
        get { pixels[y * width + x] }
        set { pixels[y * width + x] = newValue }
    }
}

// MARK: - 알약 크롭 → 흰 배경 흑백

extension GrayImage {

    /// 알약 크롭(투명 배경 RGBA) → 흰 배경 흑백. 두 모델 참조 코드의 `load_crop`·`load_face` 와 **같은 절차**다.
    ///
    /// 1. **컬러 상태에서** 흰 배경에 합성 — float32 로 `c·α + 255·(1 − α)` 후 절삭(`astype(uint8)`)
    /// 2. `cv2.COLOR_BGR2GRAY` — OpenCV 4.x 의 15비트 고정소수점
    ///
    /// 순서를 바꾸면(흑백 먼저, 알파 나중) 세그 마스크 가장자리의 반투명 띠가 달라진다. 마크 모델 문서의 경고:
    /// 흑백 변환만 바꿔도(화소 18% 에서 밝기 1단계) 한 면의 유무 점수가 0.375 → 0.597 로 움직였다.
    ///
    /// 세그 크롭은 미리 곱한(premultiplied) 알파로 온다. 반투명 가장자리 화소는 곱할 때 정밀도를 잃어
    /// 파이썬(곱하지 않은 PNG)과 ±1 다를 수 있다 — 알약 안쪽(불투명)은 같다.
    public init?(pillCrop image: CGImage) {
        guard let (rgba, width, height) = Self.straightRGBA(image) else { return nil }
        self.init(straightRGBA: rgba, width: width, height: height)
    }

    /// 곱하지 않은(straight) RGBA 바이트에서. 대조 테스트가 파이썬 `imread` 값을 그대로 넣는 입구다.
    public init(straightRGBA rgba: [UInt8], width: Int, height: Int) {
        precondition(rgba.count == width * height * 4)
        var gray = [UInt8](repeating: 255, count: width * height)
        rgba.withUnsafeBufferPointer { src in
            for i in 0..<(width * height) {
                let a = src[i * 4 + 3]
                var r = src[i * 4], g = src[i * 4 + 1], b = src[i * 4 + 2]
                if a != 255 {
                    let alpha = Float(a) / 255
                    let background = 255 * (1 - alpha)
                    r = UInt8(Float(r) * alpha + background)   // 절삭 — numpy astype(uint8)
                    g = UInt8(Float(g) * alpha + background)
                    b = UInt8(Float(b) * alpha + background)
                }
                gray[i] = OpenCV.bgrToGray(b: b, g: g, r: r)
            }
        }
        self.init(pixels: gray, width: width, height: height)
    }

    /// 곱해지지 않은(straight) RGBA. 파이썬은 PNG 를 곱하지 않은 값으로 읽는다.
    ///
    /// 8비트 RGBA 면 바이트를 그대로 읽는다 — `CGContext` 에 그리면 미리 곱한(premultiplied) 값이 되어
    /// 반투명 화소가 한 번 더 뭉개진다. 그 밖의 형식(16비트 PNG 등)만 그려서 푼다.
    private static func straightRGBA(_ image: CGImage) -> ([UInt8], Int, Int)? {
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return nil }

        let alphaInfo = image.alphaInfo
        let isRGBA8 = image.bitsPerComponent == 8 && image.bitsPerPixel == 32
            && image.colorSpace?.model == .rgb
            && (image.byteOrderInfo == .orderDefault || image.byteOrderInfo == .order32Big)
            && [.last, .premultipliedLast, .noneSkipLast].contains(alphaInfo)

        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        var premultiplied = true

        if isRGBA8, let data = image.dataProvider?.data, let base = CFDataGetBytePtr(data) {
            let rowBytes = image.bytesPerRow
            guard CFDataGetLength(data) >= rowBytes * (height - 1) + width * 4 else { return nil }
            rgba.withUnsafeMutableBufferPointer { dst in
                for y in 0..<height {
                    memcpy(dst.baseAddress! + y * width * 4, base + y * rowBytes, width * 4)
                }
            }
            if alphaInfo == .noneSkipLast {
                for i in 0..<(width * height) { rgba[i * 4 + 3] = 255 }
            }
            premultiplied = alphaInfo == .premultipliedLast
        } else {
            let drawn = rgba.withUnsafeMutableBytes { buffer -> Bool in
                guard let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else { return false }
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                return true
            }
            guard drawn else { return nil }
        }

        if premultiplied {
            for i in 0..<(width * height) {
                let a = Int(rgba[i * 4 + 3])
                guard a > 0, a < 255 else { continue }
                for c in 0..<3 {
                    rgba[i * 4 + c] = UInt8(min(255, (Int(rgba[i * 4 + c]) * 255 + a / 2) / a))
                }
            }
        }
        return (rgba, width, height)
    }
}
