import UIKit
import SnapKit
import Then
import DSKit

// ⑧ 속성 Row의 탭 가능한 칩 (선행 글리프 + 텍스트 + chevron-down)
final class AttributeChipButton: UIControl {

    private let leadingContainer = UIView()
    private let valueLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.medium.font(size: 13)
        $0.textColor = DSColor.textPrimary
    }
    private let chevron = UIImageView().then {
        $0.image = UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold))
        $0.tintColor = DSColor.textTertiary
        $0.contentMode = .scaleAspectFit
    }

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = DSColor.Neutral._100
        layer.cornerRadius = 8

        let stack = UIStackView(arrangedSubviews: [leadingContainer, valueLabel, chevron]).then {
            $0.axis = .horizontal
            $0.spacing = 4
            $0.alignment = .center
            $0.isUserInteractionEnabled = false
        }
        addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(4)
            $0.leading.trailing.equalToSuperview().inset(8)
        }
        chevron.snp.makeConstraints { $0.width.height.equalTo(12) }
    }

    func configure(leading: UIView?, value: String) {
        leadingContainer.subviews.forEach { $0.removeFromSuperview() }
        if let leading {
            leadingContainer.isHidden = false
            leadingContainer.addSubview(leading)
            leading.snp.makeConstraints { $0.edges.equalToSuperview() }
        } else {
            leadingContainer.isHidden = true
        }
        valueLabel.text = value
    }

    func setExpanded(_ expanded: Bool) {
        UIView.animate(withDuration: 0.2) {
            self.chevron.transform = expanded ? CGAffineTransform(rotationAngle: .pi) : .identity
            self.backgroundColor = expanded ? DSColor.Primary._50 : DSColor.Neutral._100
        }
    }
}
