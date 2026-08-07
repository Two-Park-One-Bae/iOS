import UIKit
import DSKit

/*
 알약 식별 고지 문구 (App Store Guideline 1.4.1).

 심사 지침은 의료 관련 정보를 제공하는 앱에 "앱과 별개로 의사와 상담하라"는 고지를
 요구한다. 식별 결과를 보여주는 세 화면(⑧ 수정·⑨ 최종 결과·⑩ 세부정보)에 같은 문구를
 노출한다 — 한 곳에서만 안내하면 다른 경로로 진입한 사용자가 못 본다.

 ⑩ 세부정보는 데이터 출처(식약처)를 함께 밝혀야 해서 앞에 한 줄이 더 붙는다.
 문구·크기·색·정렬은 디자인(EAJ5I·DG8gR·C9SVV·FqGfN·gmrp5)을 그대로 따른다.
 */
enum PillDisclaimer {

    /// 세 화면 공통 고지 본문.
    static let notice = "널스메이트의 알약 식별 결과는 참고용 보조 정보입니다. "
        + "투약 전 반드시 처방 내용과 약품 라벨을 확인하시고, 최종 판단은 의료진의 확인을 따라 주세요."

    /// ⑩ 세부정보에만 붙는 데이터 출처.
    static let source = "출처: 식품의약품안전처 의약품 제품 허가정보"

    /// - parameter withSource: 출처 줄을 위에 덧붙일지 (⑩ 세부정보 전용)
    static func makeLabel(withSource: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = withSource ? "\(source)\n\(notice)" : notice
        label.font = DSKitFontFamily.Pretendard.regular.font(size: 11)
        label.textColor = DSColor.textTertiary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }
}
