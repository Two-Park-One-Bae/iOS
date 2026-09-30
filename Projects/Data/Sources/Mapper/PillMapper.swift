//
//  PillMapper.swift
//  Data
//
//  Created by 바견규 on 7/2/26.
//

import Accelerate
import Foundation

import Domain
import Networks

// MARK: - Usage

extension PillUsageEntity {
    public func toDomain() -> PillUsageModel {
        PillUsageModel(
            limit:     limit,
            remaining: remaining,
            resetAt:   Self.parseResetAt(resetAt)
        )
    }

    // resetAt은 "2026-07-18T00:00:00+09:00" 형태.
    // ISO8601DateFormatter는 엄격해서 소수점 초 유무가 옵션과 어긋나면 nil을 반환한다 — 둘 다 시도한다.
    private static let plainFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func parseResetAt(_ value: String) -> Date? {
        plainFormatter.date(from: value) ?? fractionalFormatter.date(from: value)
    }
}

extension PillAttributeResponseEntity {
    public func toDomain() -> PillAttributeResultModel {
        PillAttributeResultModel(items: items.map { $0.toDomain() }, usage: usage.toDomain())
    }
}

// MARK: - Attribute

extension PillAttributeEntity {
    public func toDomain() -> PillAttributeModel {
        PillAttributeModel(
            pillId:         pillId,
            attributeToken: attributeToken,
            // 화면이 그대로 색으로 그리는 값이라 형식이 어긋난 것은 버린다 — 잘못된 hex 하나로 견본 전체가 깨지지 않게.
            colorHexes:     colorHexes?.filter(Self.isHexColor) ?? [],
            shape:          shape?.toDomain(),
            formulation:    formulation?.toDomain(),
            error:          error
        )
    }

    /// spec pattern `^#[0-9A-Fa-f]{6}$`.
    static func isHexColor(_ value: String) -> Bool {
        value.count == 7 && value.first == "#" && value.dropFirst().allSatisfy(\.isHexDigit)
    }
}

// MARK: - Enums

extension PillColor {
    public func toDomain() -> PillColorModel? {
        switch self {
        case .white:      return .white
        case .yellow:     return .yellow
        case .orange:     return .orange
        case .pink:       return .pink
        case .red:        return .red
        case .brown:      return .brown
        case .lightGreen: return .lightGreen
        case .green:      return .green
        case .teal:       return .teal
        case .blue:       return .blue
        case .navy:       return .navy
        case .magenta:    return .magenta
        case .purple:     return .purple
        case .gray:       return .gray
        case .black:      return .black
        case .colorless:  return .colorless
        case .unknown:    return nil
        }
    }
}

extension PillShape {
    public func toDomain() -> PillShapeModel? {
        switch self {
        case .round:      return .round
        case .oval:       return .oval
        case .oblong:     return .oblong
        case .semicircle: return .semicircle
        case .triangle:   return .triangle
        case .square:     return .square
        case .diamond:    return .diamond
        case .pentagon:   return .pentagon
        case .hexagon:    return .hexagon
        case .octagon:    return .octagon
        case .other:      return .other
        case .unknown:    return nil
        }
    }
}

extension PillFormulation {
    public func toDomain() -> PillFormulationModel? {
        switch self {
        case .tablet:      return .tablet
        case .hardCapsule: return .hardCapsule
        case .softCapsule: return .softCapsule
        case .other:       return .other
        case .unknown:     return nil
        }
    }
}

extension DividingLine {
    public func toDomain() -> DividingLineModel? {
        switch self {
        case .plus:    return .plus
        case .minus:   return .minus
        // NONE 은 요청 전용이라 응답에 오지 않는다 — 와도 v0 규칙(없음 = null)대로 둔다.
        case .none, .unknown: return nil
        }
    }
}

// MARK: - Candidate

extension PillCandidateEntity {
    public func toDomain() -> PillCandidateModel {
        PillCandidateModel(
            pillCode:         pillCode,
            pillName:         pillName,
            companyName:      companyName,
            pillThumbnailUrl: pillThumbnailUrl,
            pillImageUrl:     pillImageUrl,
            // 미지의 값·누락은 정상 취급(배지 없음·조회 진행) — 안전측.
            licenseStatus:    licenseStatus?.uppercased() == "REVOKED" ? .revoked : .normal,
            front:            front?.toDomain(),
            back:             back?.toDomain()
        )
    }
}

extension PillFaceEntity {
    public func toDomain() -> PillFaceModel {
        let line: DividingLineModel?
        switch dividingLine {
        case .plus?:  line = .plus
        case .minus?: line = .minus
        default:      line = nil   // NONE · 누락 · 미지의 값 = 구분선 없음으로 보인다
        }
        return PillFaceModel(imprint: imprint, dividingLine: line, hasMark: hasMark ?? false, markCode: markCode)
    }
}

extension PillCandidateResultEntity {
    public func toDomain() -> PillCandidateResultModel {
        PillCandidateResultModel(ids: ids, candidates: candidates.map { $0.toDomain() }, truncated: truncated)
    }
}

extension PillCandidateItemsEntity {
    public func toDomain() -> PillCandidateItemsModel {
        PillCandidateItemsModel(items: items.map { $0.toDomain() }, missing: missing)
    }
}

// MARK: - Pill Detail (NM-312)

extension PillDetailEntity {
    public func toDomain() -> PillDetailModel {
        PillDetailModel(
            pillCode:       pillCode,
            name:           name,
            companyName:    companyName,
            pillImageUrl:   pillImageUrl,
            classification: classification.toDomain(),
            appearance:     appearance,
            ingredients:    ingredients.map { $0.toDomain() },
            storageMethod:  storageMethod,
            validTerm:      validTerm,
            packUnit:       packUnit,
            documents:      documents.map { $0.toDomain() }
        )
    }
}

extension IngredientEntity {
    public func toDomain() -> IngredientModel {
        IngredientModel(name: name, amount: amount, unit: unit)
    }
}

extension LicenseDocEntity {
    public func toDomain() -> LicenseDocModel {
        // 모르는 블록 타입(.unknown)은 제외 — 호환성 규칙(domains/pill-detail.md)
        LicenseDocModel(type: type.toDomain(), blocks: blocks.compactMap { $0.toDomain() })
    }
}

extension BlockEntity {
    public func toDomain() -> BlockModel? {
        switch self {
        case .heading(let content):
            return .heading(content: content.map { $0.toDomain() })
        case .paragraph(let content):
            return .paragraph(content: content.map { $0.toDomain() })
        case .table(let caption, let rows):
            return .table(caption: caption?.map { $0.toDomain() }, rows: rows.map { $0.toDomain() })
        case .image(let src):
            return .image(src: src)
        case .unknown:
            return nil
        }
    }
}

extension TableRowEntity {
    public func toDomain() -> TableRowModel {
        TableRowModel(cells: cells.map { $0.toDomain() })
    }
}

extension TableCellEntity {
    public func toDomain() -> TableCellModel {
        TableCellModel(
            content: content.map { $0.toDomain() },
            colspan: colspan,
            rowspan: rowspan,
            header:  header
        )
    }
}

extension SpanEntity {
    public func toDomain() -> SpanModel {
        SpanModel(text: text, style: style?.toDomain())
    }
}

extension PillClassification {
    public func toDomain() -> PillClassificationModel {
        switch self {
        case .etc:     return .etc
        case .otc:     return .otc
        case .unknown: return .unknown
        }
    }
}

extension LicenseDocType {
    public func toDomain() -> LicenseDocTypeModel {
        switch self {
        case .effect:  return .effect
        case .dosage:  return .dosage
        case .caution: return .caution
        case .unknown: return .unknown
        }
    }
}

extension SpanStyle {
    // 모르는 style은 일반 텍스트로 렌더 → nil
    public func toDomain() -> SpanStyleModel? {
        switch self {
        case .sup:     return .sup
        case .sub:     return .sub
        case .unknown: return nil
        }
    }
}

// MARK: - Domain → Network (Request 변환용)

extension PillColorModel {
    public func toNetwork() -> PillColor? {
        switch self {
        case .white:      return .white
        case .yellow:     return .yellow
        case .orange:     return .orange
        case .pink:       return .pink
        case .red:        return .red
        case .brown:      return .brown
        case .lightGreen: return .lightGreen
        case .green:      return .green
        case .teal:       return .teal
        case .blue:       return .blue
        case .navy:       return .navy
        case .magenta:    return .magenta
        case .purple:     return .purple
        case .gray:       return .gray
        case .black:      return .black
        case .colorless:  return .colorless
        case .unknown:    return nil
        }
    }
}

extension PillShapeModel {
    public func toNetwork() -> PillShape? {
        switch self {
        case .round:      return .round
        case .oval:       return .oval
        case .oblong:     return .oblong
        case .semicircle: return .semicircle
        case .triangle:   return .triangle
        case .square:     return .square
        case .diamond:    return .diamond
        case .pentagon:   return .pentagon
        case .hexagon:    return .hexagon
        case .octagon:    return .octagon
        case .other:      return .other
        case .unknown:    return nil
        }
    }
}

extension PillFormulationModel {
    public func toNetwork() -> PillFormulation? {
        switch self {
        case .tablet:      return .tablet
        case .hardCapsule: return .hardCapsule
        case .softCapsule: return .softCapsule
        case .other:       return .other
        case .unknown:     return nil
        }
    }
}

extension DividingLineModel {
    public func toNetwork() -> DividingLine? {
        switch self {
        case .plus:    return .plus
        case .minus:   return .minus
        case .unknown: return nil
        }
    }
}

// MARK: - Candidate Request

extension PillCandidateQuery {
    public func toNetwork() -> PillCandidateRequest {
        PillCandidateRequest(
            attributeToken: attributeToken,
            colors:         colors.compactMap { $0.toNetwork() },
            shape:          shape?.toNetwork(),
            formulation:    formulation?.toNetwork(),
            front:          front?.toNetwork(),
            back:           back?.toNetwork()
        )
    }
}

extension PillFaceQuery {
    public func toNetwork() -> PillFaceRequest {
        let line: DividingLine?
        switch dividingLine {
        case .none?:  line = DividingLine.none
        case .plus?:  line = .plus
        case .minus?: line = .minus
        case nil:     line = nil
        }
        return PillFaceRequest(
            imprint:       imprint,
            // imprint 가 있을 때만 — 출처만 보내면 서버가 400 을 낸다.
            imprintSource: imprint == nil ? nil : (imprintSource == .user ? "USER" : "MODEL"),
            dividingLine:  line,
            hasMark:       hasMark,
            markEmbedding: embedding.flatMap(MarkEmbeddingEncoder.base64)
        )
    }
}

/// 마크 임베딩 → 요청 문자열. base64 · fp16 · little-endian · 8×768 row-major(회전 8개가 바깥).
///
/// 모델이 L2 정규화한 값을 그대로 보낸다 — 서버는 다시 정규화하지 않는다.
enum MarkEmbeddingEncoder {
    static let rotations = 8
    static let dimension = 768

    /// 길이가 8×768 이 아니면 nil — 모양이 틀린 값을 보내 후보 조회 전체가 400 이 되느니 임베딩 항만 뺀다.
    static func base64(_ embedding: [Float]) -> String? {
        guard embedding.count == rotations * dimension else { return nil }
        var halves = [UInt16](repeating: 0, count: embedding.count)
        let converted = embedding.withUnsafeBufferPointer { src in
            halves.withUnsafeMutableBufferPointer { dst -> Bool in
                var source = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: src.baseAddress!),
                                           height: 1, width: vImagePixelCount(src.count),
                                           rowBytes: src.count * MemoryLayout<Float>.size)
                var destination = vImage_Buffer(data: dst.baseAddress!,
                                                height: 1, width: vImagePixelCount(dst.count),
                                                rowBytes: dst.count * MemoryLayout<UInt16>.size)
                return vImageConvert_PlanarFtoPlanar16F(&source, &destination, 0) == kvImageNoError
            }
        }
        guard converted else { return nil }
        let data = halves.withUnsafeBufferPointer { buffer in
            Data(buffer: UnsafeBufferPointer(start: buffer.baseAddress, count: buffer.count))
        }
        // iOS 기기는 모두 little-endian — UInt16 메모리 그대로가 곧 LE 바이트다.
        return data.base64EncodedString()
    }
}
