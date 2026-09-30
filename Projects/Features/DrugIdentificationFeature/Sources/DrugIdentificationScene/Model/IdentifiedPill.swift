import UIKit
import Domain

// 인식 결과 화면에 표시할 알약 1개 (크롭 이미지 + 속성 + 정규화 bbox)
struct IdentifiedPill {
    /// 이 식별 흐름 안의 고정 식별자. 화면에 보이는 번호는 삭제·추가 때 다시 매기므로 이것과 다를 수 있다.
    let index: Int
    /// 속성 추출 요청·응답의 매핑 키 — 요청 안에서 고유해야 한다(중복이면 서버 400).
    let pillId: String
    let thumbnail: UIImage?
    let boundingBox: CGRect   // 원본 대비 정규화 (0~1)
    /// 서버 속성 추출 결과(/api/v1). 응답 전·수동 추가 알약은 nil.
    let attribute: PillAttributeModel?

    /// 서버가 알약을 통째로 판정하지 못함(EXTRACTION_FAILED) — 결과 카드 '정보 인식 실패'.
    var isExtractionFailed: Bool { attribute?.error != nil }

    /// 수정 화면 조건의 원본(모델 출력). 추출 실패·수동 추가는 서버 값이 없다.
    /// 각인·마크는 온디바이스 추론(NM-459 · NM-512)이 붙으면 여기로 들어온다.
    var modelOutput: PillModelOutput {
        attribute.map { PillModelOutput(attribute: $0) } ?? .empty
    }
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

    // 결과행 칩용 축약명
    var shortName: String {
        switch self {
        case .tablet:      return "정제"
        case .hardCapsule: return "경질"
        case .softCapsule: return "연질"
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
