import UIKit
import SnapKit
import DSKit
import Domain

// ⑩-d 주의사항 — HEADING을 접기 단위로 하는 아코디언 섹션.
// 헤더 탭 시 하위 블록(content) 표시/숨김 토글.
final class PillDetailAccordionSection: UIView {

    private let contentStack = UIStackView()
    private let chevron = UIImageView()
    private var expanded: Bool

    init(title: [SpanModel], contentViews: [UIView], expanded: Bool) {
        self.expanded = expanded
        super.init(frame: .zero)
        build(title: title, contentViews: contentViews)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build(title: [SpanModel], contentViews: [UIView]) {
        backgroundColor = DSColor.surface
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = DSColor.border.cgColor
        clipsToBounds = true

        let titleLabel = UILabel()
        titleLabel.numberOfLines = 0
        titleLabel.attributedText = PillDetailRenderer.attributedString(
            from: title,
            font: DSKitFontFamily.Pretendard.semiBold.font(size: 15),
            color: DSColor.textPrimary,
            lineHeightMultiple: 1.3
        )
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        chevron.image = DSIcon.chevronDown.uiImage
        chevron.tintColor = DSColor.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.snp.makeConstraints { $0.width.height.equalTo(20) }

        let header = UIStackView(arrangedSubviews: [titleLabel, chevron])
        header.axis = .horizontal
        header.spacing = 8
        header.alignment = .center
        header.isLayoutMarginsRelativeArrangement = true
        header.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        header.isUserInteractionEnabled = true
        header.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggle)))

        contentStack.axis = .vertical
        contentStack.spacing = 10
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)
        contentViews.forEach { contentStack.addArrangedSubview($0) }
        contentStack.isHidden = !expanded

        let root = UIStackView(arrangedSubviews: [header, contentStack])
        root.axis = .vertical
        root.spacing = 0
        addSubview(root)
        root.snp.makeConstraints { $0.edges.equalToSuperview() }

        updateChevron()
    }

    @objc private func toggle() {
        expanded.toggle()
        UIView.animate(withDuration: 0.2) {
            self.contentStack.isHidden = !self.expanded
            self.updateChevron()
            self.superview?.layoutIfNeeded()
        }
    }

    private func updateChevron() {
        chevron.transform = expanded ? CGAffineTransform(rotationAngle: .pi) : .identity
    }
}
