import UIKit
import SnapKit
import Then
import DSKit

// 식별 결과 하단 "+ 알약 추가" 버튼 — NM-187 수동 추가 진입.
// V2.1.0: 흰 볼록 버튼(raisedNeutral, r12), padding (12, 16), 아이콘 18 · SemiBold 14 Primary700
final class AddPillButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.85 : 1 }
    }

    private func setup() {
        let surface = DSSurfaceView(spec: .raisedNeutral(), cornerRadius: DSRadius.md)
        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(surface)

        let icon = UIImageView().then {
            $0.image = DSIcon.plus.uiImage
            $0.tintColor = DSColor.Primary._700
            $0.contentMode = .scaleAspectFit
            $0.isUserInteractionEnabled = false
        }
        icon.snp.makeConstraints { $0.width.height.equalTo(18) }

        let label = UILabel().then {
            $0.text = "알약 추가"
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 14)
            $0.textColor = DSColor.Primary._700
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
            $0.top.bottom.equalToSuperview().inset(12)
            $0.leading.greaterThanOrEqualToSuperview().inset(14)
            $0.trailing.lessThanOrEqualToSuperview().inset(14)
        }
    }
}
