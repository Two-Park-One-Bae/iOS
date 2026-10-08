//
//  DSCheckbox.swift
//  DSKit
//
//  Created by 바견규 on 8/28/26.
//

import UIKit
import SnapKit

/// 둥근 사각 체크박스 (디자인: DESIGN.pen `b6vnhN` 동의 온보딩).
///
/// 선택하면 Primary 로 채우고 흰 체크를, 해제하면 흰 배경에 Neutral 테두리를 그린다.
/// 탭 처리는 이 뷰가 하지 않는다 — 실제 히트 영역은 행 전체라, 행이 상태만 내려준다.
public final class DSCheckbox: UIView {

    /// 전체 동의(26)와 개별 항목(22)의 크기가 다르다.
    public enum Size {
        case large
        case small

        var length: CGFloat {
            switch self {
            case .large: return 26
            case .small: return 22
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .large: return 8
            case .small: return 7
            }
        }

        var checkLength: CGFloat {
            switch self {
            case .large: return 16
            case .small: return 14
            }
        }
    }

    public private(set) var isChecked: Bool = false
    /// 바꿀 수 없는 항목(예: 약관 및 동의 화면의 필수 항목)은 Neutral 로 눌러 둔다 (디자인 NM-548).
    public private(set) var isEnabled: Bool = true

    private let checkView = UIImageView()

    public init(size: Size = .small, isChecked: Bool = false) {
        super.init(frame: .zero)
        setup(size: size)
        setChecked(isChecked)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(size: Size) {
        layer.cornerRadius = size.cornerRadius
        layer.borderWidth = 1.5

        snp.makeConstraints {
            $0.width.height.equalTo(size.length)
        }

        checkView.image = DSIcon.check.uiImage
        checkView.tintColor = .white
        checkView.contentMode = .scaleAspectFit
        addSubview(checkView)
        checkView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.height.equalTo(size.checkLength)
        }
    }

    public func setChecked(_ checked: Bool) {
        isChecked = checked
        render()
    }

    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        render()
    }

    private func render() {
        let fill = isEnabled ? DSColor.Primary._500 : DSColor.Neutral._300
        backgroundColor = isChecked ? fill : DSColor.Neutral._0
        layer.borderColor = (isChecked ? fill : DSColor.Neutral._200).cgColor
        checkView.isHidden = !isChecked
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DSCheckbox") {
    let locked = DSCheckbox(size: .small, isChecked: true)
    locked.setEnabled(false)
    let stack = UIStackView(arrangedSubviews: [
        DSCheckbox(size: .large, isChecked: true),
        DSCheckbox(size: .small, isChecked: false),
        locked,
    ])
    stack.spacing = 12
    stack.alignment = .center
    return stack
}
#endif
