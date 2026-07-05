import UIKit
import SnapKit
import Then
import DSKit

// 인식 결과 하단 "+ 알약 추가" 버튼 — NM-187 수동 추가 진입
final class AddPillButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = DSColor.Primary._50
        layer.cornerRadius = 14
        layer.borderWidth = 1.5
        layer.borderColor = DSColor.Primary._300.cgColor

        let icon = UIImageView().then {
            $0.image = DSIcon.plus.uiImage
            $0.tintColor = DSColor.Primary._600
            $0.contentMode = .scaleAspectFit
            $0.isUserInteractionEnabled = false
        }
        icon.snp.makeConstraints { $0.width.height.equalTo(18) }

        let label = UILabel().then {
            $0.text = "알약 추가"
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 14)
            $0.textColor = DSColor.Primary._600
            $0.isUserInteractionEnabled = false
        }

        let stack = UIStackView(arrangedSubviews: [icon, label]).then {
            $0.axis = .horizontal
            $0.spacing = 6
            $0.alignment = .center
            $0.isUserInteractionEnabled = false
        }

        addSubview(stack)
        stack.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.top.bottom.equalToSuperview().inset(14)
            $0.leading.greaterThanOrEqualToSuperview().inset(14)
            $0.trailing.lessThanOrEqualToSuperview().inset(14)
        }
    }
}
