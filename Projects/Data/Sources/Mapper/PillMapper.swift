//
//  PillMapper.swift
//  Data
//
//  Created by 바견규 on 7/2/26.
//

import Domain
import Networks

// MARK: - Attribute

extension PillAttributeEntity {
    public func toDomain() -> PillAttributeModel {
        PillAttributeModel(
            pillId:        pillId,
            colors:        colors?.compactMap { $0.toDomain() } ?? [],
            isTransparent: isTransparent,
            shape:         shape?.toDomain(),
            formulation:   formulation?.toDomain(),
            front:         front?.toDomain(),
            back:          back?.toDomain(),
            error:         error
        )
    }
}

extension PillFaceEntity {
    public func toDomain() -> PillFaceModel {
        PillFaceModel(
            imprint:      imprint,
            dividingLine: dividingLine?.toDomain(),
            hasMark:      hasMark
        )
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
        case .unknown: return nil
        }
    }
}

// MARK: - Candidate

extension PillCandidateEntity {
    public func toDomain() -> PillCandidateModel {
        PillCandidateModel(
            pillCode:     pillCode,
            pillName:     pillName,
            companyName:  companyName,
            pillImageUrl: pillImageUrl
        )
    }
}

extension PillCandidatePageEntity {
    public func toDomain() -> PillCandidatePageModel {
        PillCandidatePageModel(
            candidates:    candidates.map { $0.toDomain() },
            page:          page,
            size:          size,
            totalElements: totalElements,
            totalPages:    totalPages
        )
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

extension PillFaceModel {
    public func toNetwork() -> PillFaceRequest {
        PillFaceRequest(
            imprint:      imprint,
            dividingLine: dividingLine?.toNetwork(),
            hasMark:      hasMark
        )
    }
}
