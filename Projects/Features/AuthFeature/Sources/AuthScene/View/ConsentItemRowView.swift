//
//  ConsentItemRowView.swift
//  AuthFeature
//
//  Created by 바견규 on 8/28/26.
//

import UIKit

import DSKit
import Domain
import SnapKit
import Then

/// 동의 항목 한 줄 — [체크박스] [필수] 제목 ......... 보기 >
///
/// 체크박스와 '보기'의 히트 영역이 다르다. 행 아무 데나 누르면 체크가 토글되고,
/// '보기'만 문서를 연다 — 문서를 보려다 실수로 동의되는 일이 없게.
final class ConsentItemRowView: UIView {

    private let definition: ConsentDefinition
    private let onToggle: () -> Void
    private let onOpenPolicy: () -> Void

    private let checkbox = DSCheckbox(size: .small)

    init(
        definition: ConsentDefinition,
        onToggle: @escaping () -> Void,
        onOpenPolicy: @escaping () -> Void
    ) {
        self.definition = definition
        self.onToggle = onToggle
        self.onOpenPolicy = onOpenPolicy
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    func setChecked(_ checked: Bool) {
        checkbox.setChecked(checked)
    }

    private func setup() {
        let requiredLabel = UILabel().then {
            $0.text = definition.isRequired ? "필수" : "선택"
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 12)
            $0.textColor = DSColor.Primary._600
        }

        let titleLabel = UILabel().then {
            $0.text = definition.title
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 15)
            $0.textColor = DSColor.textPrimary
        }

        let labelStack = UIStackView(arrangedSubviews: [requiredLabel, titleLabel]).then {
            $0.axis = .horizontal
            $0.spacing = 6
            $0.alignment = .center
        }

        let (policyButton, policyRecognizer) = makePolicyButton()
        // 문서 URL 이 없으면(서버가 못 여는 값을 준 경우) '보기' 를 아예 감춘다 —
        // 눌러도 아무 일 없는 버튼은 고장으로 보인다.
        policyButton.isHidden = (definition.policyUrl == nil)

        let rowStack = UIStackView(arrangedSubviews: [checkbox, labelStack, UIView(), policyButton]).then {
            $0.axis = .horizontal
            $0.spacing = 12
            $0.alignment = .center
        }

        addSubview(rowStack)
        rowStack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(14)
            $0.leading.trailing.equalToSuperview().inset(4)
        }

        // 행 전체가 체크 토글.
        // 조상의 제스처는 자식이 터치를 먹어도 함께 인식되므로, '보기'가 인식되면 행 탭은 취소되도록
        // 명시적으로 순서를 준다 — 없으면 '보기'를 누를 때 체크까지 토글된다.
        let rowRecognizer = UITapGestureRecognizer(target: self, action: #selector(rowTapped))
        rowRecognizer.require(toFail: policyRecognizer)
        addGestureRecognizer(rowRecognizer)
    }

    private func makePolicyButton() -> (view: UIView, recognizer: UITapGestureRecognizer) {
        let label = UILabel().then {
            $0.text = "보기"
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
            $0.textColor = DSColor.textSecondary
        }

        let chevron = UIImageView().then {
            $0.image = DSIcon.chevronRight.uiImage
            $0.tintColor = DSColor.Neutral._400
            $0.contentMode = .scaleAspectFit
        }
        chevron.snp.makeConstraints { $0.width.height.equalTo(16) }

        let stack = UIStackView(arrangedSubviews: [label, chevron]).then {
            $0.axis = .horizontal
            $0.spacing = 2
            $0.alignment = .center
            $0.isUserInteractionEnabled = true
        }
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(policyTapped))
        stack.addGestureRecognizer(recognizer)
        return (stack, recognizer)
    }

    @objc private func rowTapped() { onToggle() }

    @objc private func policyTapped() { onOpenPolicy() }
}
