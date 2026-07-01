import CoreML
import Foundation
import ImageIO
import UIKit

public struct RFDetection: Identifiable, Sendable {
    public let id: Int
    public let score: Float
    public let box: CGRect
    public let maskLogits: [Float]
}

public struct RFDETRResult: Sendable {
    public let detections: [RFDetection]
    public let preprocessTime: TimeInterval
    public let inferenceTime: TimeInterval
    public let decodeTime: TimeInterval
}

public struct TransferSizeReport {
    public let cropsCount: Int
    public let cropsPNGBytes: Int
    public let cropsJPEGBytes: Int
    public let originalBytes: Int
}

public enum RFDETRError: LocalizedError {
    case missingModel
    case imageConversion
    case missingOutput(String)
    case invalidOutput(String)

    public var errorDescription: String? {
        switch self {
        case .missingModel:            return "앱 번들에서 rfdetr_seg_small_fp32.mlmodelc를 찾지 못했습니다."
        case .imageConversion:         return "이미지를 RGB 입력 텐서로 변환하지 못했습니다."
        case .missingOutput(let name): return "CoreML 출력이 없습니다: \(name)"
        case .invalidOutput(let name): return "CoreML 출력 형식이 잘못되었습니다: \(name)"
        }
    }
}

public struct CroppedDetection: Identifiable {
    public let id = UUID()
    public let image: UIImage
    public let score: Float
    public let pixelSize: CGSize
}

public final class RFDetrSegmentor: @unchecked Sendable {
    public static let inputSize  = 576
    public static let queryCount = 100
    public static let maskSize   = 144

    private let model: MLModel

    public static func makeInferenceImage(from data: Data) throws -> UIImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw RFDETRError.imageConversion
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: inputSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw RFDETRError.imageConversion
        }
        return UIImage(cgImage: cg)
    }

    public static func makeOriginalNormalizedImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 12_000,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    public static func cropDetections(
        from original: UIImage,
        detections: [RFDetection],
        originalDataSize: Int = 0
    ) -> (crops: [CroppedDetection], time: TimeInterval, transferReport: TransferSizeReport) {
        let empty = TransferSizeReport(cropsCount: 0, cropsPNGBytes: 0, cropsJPEGBytes: 0, originalBytes: originalDataSize)
        guard let cgImage = original.cgImage else { return ([], 0, empty) }
        let started = CFAbsoluteTimeGetCurrent()
        let crops = detections.compactMap { cropWithMask(cgImage: cgImage, detection: $0) }
        let time = CFAbsoluteTimeGetCurrent() - started

        var pngTotal = 0, jpegTotal = 0
        for crop in crops {
            pngTotal += crop.image.pngData()?.count ?? 0
            let flatSize = crop.image.size
            let flat = UIGraphicsImageRenderer(size: flatSize).image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: flatSize))
                crop.image.draw(in: CGRect(origin: .zero, size: flatSize))
            }
            jpegTotal += flat.jpegData(compressionQuality: 0.9)?.count ?? 0
        }
        return (crops, time, TransferSizeReport(cropsCount: crops.count, cropsPNGBytes: pngTotal, cropsJPEGBytes: jpegTotal, originalBytes: originalDataSize))
    }

    private static func cropWithMask(cgImage: CGImage, detection: RFDetection) -> CroppedDetection? {
        let origW = cgImage.width, origH = cgImage.height
        let ms = maskSize

        var dx0 = ms, dx1 = -1, dy0 = ms, dy1 = -1
        for my in 0..<ms {
            for mx in 0..<ms where detection.maskLogits[my * ms + mx] > 0 {
                let dy = ms - 1 - my
                dx0 = min(dx0, mx); dx1 = max(dx1, mx)
                dy0 = min(dy0, dy); dy1 = max(dy1, dy)
            }
        }
        guard dx1 >= dx0, dy1 >= dy0 else { return nil }

        let px0 = dx0 * origW / ms, py0 = dy0 * origH / ms
        let cropW = (dx1 + 1) * origW / ms - px0
        let cropH = (dy1 + 1) * origH / ms - py0
        guard cropW > 0, cropH > 0,
              let cropped = cgImage.cropping(to: CGRect(x: px0, y: py0, width: cropW, height: cropH))
        else { return nil }

        var rgba = [UInt8](repeating: 0, count: cropW * cropH * 4)
        guard let ctx = CGContext(
            data: &rgba, width: cropW, height: cropH,
            bitsPerComponent: 8, bytesPerRow: cropW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: cropW, height: cropH))

        let fms = Float(ms), fW = Float(origW), fH = Float(origH)
        for py in 0..<cropH {
            let imgY = Float(py0) + Float(py) + 0.5
            let myf  = (fH - imgY) * fms / fH - 0.5
            let my0i = max(0, min(ms - 2, Int(myf)))
            let fy   = max(0, min(1, myf - Float(my0i)))
            for px in 0..<cropW {
                let imgX = Float(px0) + Float(px) + 0.5
                let mxf  = imgX * fms / fW - 0.5
                let mx0i = max(0, min(ms - 2, Int(mxf)))
                let fx   = max(0, min(1, mxf - Float(mx0i)))
                let l00  = detection.maskLogits[ my0i      * ms +  mx0i     ]
                let l10  = detection.maskLogits[ my0i      * ms + (mx0i + 1)]
                let l01  = detection.maskLogits[(my0i + 1) * ms +  mx0i     ]
                let l11  = detection.maskLogits[(my0i + 1) * ms + (mx0i + 1)]
                let logit = l00*(1-fx)*(1-fy) + l10*fx*(1-fy) + l01*(1-fx)*fy + l11*fx*fy
                let alpha = UInt8(max(0, min(255, Int(sigmoid(logit) * 255 + 0.5))))
                let base  = (py * cropW + px) * 4
                if alpha == 0 {
                    rgba[base] = 0; rgba[base+1] = 0; rgba[base+2] = 0
                } else if alpha < 255 {
                    rgba[base]   = UInt8(Int(rgba[base])   * Int(alpha) / 255)
                    rgba[base+1] = UInt8(Int(rgba[base+1]) * Int(alpha) / 255)
                    rgba[base+2] = UInt8(Int(rgba[base+2]) * Int(alpha) / 255)
                }
                rgba[base + 3] = alpha
            }
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let result = CGImage(
                width: cropW, height: cropH,
                bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: cropW * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
              ) else { return nil }
        return CroppedDetection(image: UIImage(cgImage: result), score: detection.score, pixelSize: CGSize(width: cropW, height: cropH))
    }

    public init() throws {
        guard let url = Bundle(for: RFDetrSegmentor.self).url(forResource: "rfdetr_seg_small_fp32", withExtension: "mlmodelc") else {
            throw RFDETRError.missingModel
        }
        let config = MLModelConfiguration()
        config.computeUnits = .all
        model = try MLModel(contentsOf: url, configuration: config)
    }

    public func run(image: UIImage) throws -> RFDETRResult {
        let preprocessStarted = CFAbsoluteTimeGetCurrent()
        let inputArray = try Self.makeInputArray(from: image)
        let featureProvider = try MLDictionaryFeatureProvider(dictionary: ["image": inputArray])
        let preprocessTime = CFAbsoluteTimeGetCurrent() - preprocessStarted

        let inferenceStarted = CFAbsoluteTimeGetCurrent()
        let result = try model.prediction(from: featureProvider)
        let inferenceTime = CFAbsoluteTimeGetCurrent() - inferenceStarted

        let decodeStarted = CFAbsoluteTimeGetCurrent()

        guard let logitsArray = result.featureValue(for: "pred_logits")?.multiArrayValue,
              let boxesArray  = result.featureValue(for: "pred_boxes")?.multiArrayValue,
              let masksArray  = result.featureValue(for: "pred_masks")?.multiArrayValue
        else { throw RFDETRError.missingOutput("pred_logits / pred_boxes / pred_masks") }

        let logits = floatsFrom(logitsArray)
        let boxes  = floatsFrom(boxesArray)
        let masks  = floatsFrom(masksArray)

        guard logits.count == Self.queryCount * 2 else { throw RFDETRError.invalidOutput("pred_logits") }
        guard boxes.count  == Self.queryCount * 4 else { throw RFDETRError.invalidOutput("pred_boxes")  }
        guard masks.count  == Self.queryCount * Self.maskSize * Self.maskSize else {
            throw RFDETRError.invalidOutput("pred_masks")
        }

        let ms = Self.maskSize
        let detections: [RFDetection] = (0..<Self.queryCount).map { q in
            let score = sigmoid(logits[q * 2])
            let cx = boxes[q * 4], cy = boxes[q * 4 + 1]
            let w  = boxes[q * 4 + 2], h = boxes[q * 4 + 3]
            let x1 = max(0, min(1, cx - w / 2))
            let x2 = max(0, min(1, cx + w / 2))
            let y1 = max(0, min(1, 1 - (cy + h / 2)))
            let y2 = max(0, min(1, 1 - (cy - h / 2)))
            let start = q * ms * ms
            return RFDetection(
                id: q, score: score,
                box: CGRect(x: CGFloat(x1), y: CGFloat(y1),
                            width: CGFloat(max(0, x2 - x1)), height: CGFloat(max(0, y2 - y1))),
                maskLogits: Array(masks[start ..< start + ms * ms])
            )
        }

        return RFDETRResult(
            detections: detections,
            preprocessTime: preprocessTime,
            inferenceTime: inferenceTime,
            decodeTime: CFAbsoluteTimeGetCurrent() - decodeStarted
        )
    }

    public static func makeMaskOverlay(from detections: [RFDetection]) -> UIImage? {
        guard !detections.isEmpty else { return nil }
        let ms = maskSize
        var rgba = [UInt8](repeating: 0, count: ms * ms * 4)
        let masks = detections.map(\.maskLogits)
        for y in 0..<ms {
            for x in 0..<ms {
                let modelPixel = y * ms + x
                guard masks.contains(where: { $0[modelPixel] > 0 }) else { continue }
                let displayPixel = (ms - 1 - y) * ms + x
                rgba[displayPixel * 4]     = 0
                rgba[displayPixel * 4 + 1] = 255
                rgba[displayPixel * 4 + 2] = 80
                rgba[displayPixel * 4 + 3] = 105
            }
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let cgImage = CGImage(
                width: ms, height: ms,
                bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: ms * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              ) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Private

    private static func makeInputArray(from image: UIImage) throws -> MLMultiArray {
        guard let cgImage = normalizedCGImage(from: image) else { throw RFDETRError.imageConversion }
        let side = inputSize
        var rgba = [UInt8](repeating: 0, count: side * side * 4)
        guard let ctx = CGContext(
            data: &rgba, width: side, height: side,
            bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw RFDETRError.imageConversion }
        ctx.interpolationQuality = .high
        ctx.translateBy(x: 0, y: CGFloat(side))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        let array = try MLMultiArray(shape: [1, 3, side as NSNumber, side as NSNumber], dataType: .float32)
        let plane = side * side
        let scales: [Float]  = [1 / (255 * 0.229), 1 / (255 * 0.224), 1 / (255 * 0.225)]
        let offsets: [Float] = [-0.485 / 0.229,    -0.456 / 0.224,    -0.406 / 0.225   ]
        let ptr = array.dataPointer.bindMemory(to: Float32.self, capacity: 3 * plane)
        rgba.withUnsafeBufferPointer { pixels in
            DispatchQueue.concurrentPerform(iterations: side) { y in
                let rowStart = y * side
                for x in 0..<side {
                    let p = rowStart + x
                    let r = pixels[p * 4], g = pixels[p * 4 + 1], b = pixels[p * 4 + 2]
                    ptr[p]           = Float(r) * scales[0] + offsets[0]
                    ptr[plane + p]   = Float(g) * scales[1] + offsets[1]
                    ptr[plane*2 + p] = Float(b) * scales[2] + offsets[2]
                }
            }
        }
        return array
    }

    private static func normalizedCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cg = image.cgImage { return cg }
        return UIGraphicsImageRenderer(size: image.size)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
            .cgImage
    }

    private func floatsFrom(_ array: MLMultiArray) -> [Float] {
        let count = array.count
        let ptr = array.dataPointer
        switch array.dataType {
        case .float32, .float:
            return Array(UnsafeBufferPointer(start: ptr.bindMemory(to: Float32.self, capacity: count), count: count))
        case .float16:
            let f16 = UnsafeBufferPointer(start: ptr.bindMemory(to: UInt16.self, capacity: count), count: count)
            return f16.map { float16ToFloat32($0) }
        case .double:
            let f64 = UnsafeBufferPointer(start: ptr.bindMemory(to: Double.self, capacity: count), count: count)
            return f64.map { Float($0) }
        default:
            return (0..<count).map { array[$0].floatValue }
        }
    }

    private func float16ToFloat32(_ bits: UInt16) -> Float {
        let s = Int32(bits >> 15)
        let e = Int32((bits >> 10) & 0x1F)
        let m = Int32(bits & 0x3FF)
        if e == 0 { return Float(s == 0 ? 1 : -1) * Float(m) * pow(2, -24) }
        if e == 31 { return m == 0 ? (s == 0 ? Float.infinity : -Float.infinity) : Float.nan }
        let f32Bits = UInt32((s << 31) | ((e + 112) << 23) | (m << 13))
        return Float(bitPattern: f32Bits)
    }

    private func sigmoid(_ x: Float) -> Float { Self.sigmoid(x) }
    private static func sigmoid(_ x: Float) -> Float {
        1 / (1 + exp(-max(-88, min(88, x))))
    }
}
