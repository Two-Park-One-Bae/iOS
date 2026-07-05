import UIKit
import Domain

// 인식 결과 화면에 표시할 알약 1개 (크롭 이미지 + 속성 + 정규화 bbox)
struct IdentifiedPill {
    let index: Int
    let thumbnail: UIImage?
    let boundingBox: CGRect   // 원본 대비 정규화 (0~1)
    let attribute: PillAttributeModel
}

// MARK: - Korean Display Mappers

extension PillColorModel {
    var displayName: String {
        switch self {
        case .white:      return "하양"
        case .yellow:     return "노랑"
        case .orange:     return "주황"
        case .pink:       return "분홍"
        case .red:        return "빨강"
        case .brown:      return "갈색"
        case .lightGreen: return "연두"
        case .green:      return "초록"
        case .teal:       return "청록"
        case .blue:       return "파랑"
        case .navy:       return "남색"
        case .magenta:    return "자홍"
        case .purple:     return "보라"
        case .gray:       return "회색"
        case .black:      return "검정"
        case .colorless:  return "투명"
        case .unknown:    return "미상"
        }
    }
}

extension PillShapeModel {
    var displayName: String {
        switch self {
        case .round:      return "원형"
        case .oval:       return "타원형"
        case .oblong:     return "장방형"
        case .semicircle: return "반원형"
        case .triangle:   return "삼각형"
        case .square:     return "사각형"
        case .diamond:    return "마름모"
        case .pentagon:   return "오각형"
        case .hexagon:    return "육각형"
        case .octagon:    return "팔각형"
        case .other:      return "기타"
        case .unknown:    return "미상"
        }
    }
}

extension PillFormulationModel {
    var displayName: String {
        switch self {
        case .tablet:      return "정제"
        case .hardCapsule: return "경질캡슐"
        case .softCapsule: return "연질캡슐"
        case .other:       return "기타"
        case .unknown:     return "미상"
        }
    }
}

extension DividingLineModel {
    var displayName: String {
        switch self {
        case .plus:    return "＋"
        case .minus:   return "－"
        case .unknown: return "없음"
        }
    }
}

extension PillAttributeModel {
    // "하양, 노랑" 형태
    var colorsText: String {
        guard !colors.isEmpty else { return "미상" }
        return colors.map(\.displayName).joined(separator: ", ")
    }
}
