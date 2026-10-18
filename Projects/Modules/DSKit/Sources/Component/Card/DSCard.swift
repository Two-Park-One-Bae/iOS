import UIKit

// MARK: - Card
// V2.1.0 유리 카드: 면 glassCard, cornerRadius 20, padding 20, gap 12
// Title: Pretendard SemiBold 16, textPrimary
// Body: Pretendard Regular 13, textSecondary, lineHeight 1.4
// Actions(선택): 버튼을 가로로 같은 폭, gap 8 — `setActions`

public final class DSCard: UIView {

    // MARK: - UI

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = DSKitFontFamily.Pretendard.semiBold.font(size: 16)
        label.textColor = DSColor.textPrimary
        label.numberOfLines = 0
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
        label.textColor = DSColor.textSecondary
        label.numberOfLines = 0
        return label
    }()

    private let surface = DSSurfaceView(spec: .glassCard)

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let actionStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillEqually
        stack.isHidden = true
        return stack
    }()

    // MARK: - Init

    public init(title: String, body: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        setBody(body)
        setupUI()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(surface)

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(bodyLabel)
        stackView.addArrangedSubview(actionStack)
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
}

// MARK: - Methods

extension DSCard {

    public func setTitle(_ title: String) {
        titleLabel.text = title
    }

    /// 카드 아래 버튼 줄. 빈 배열이면 줄을 숨긴다.
    public func setActions(_ buttons: [UIButton]) {
        actionStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttons.forEach(actionStack.addArrangedSubview)
        actionStack.isHidden = buttons.isEmpty
    }

    public func setBody(_ body: String) {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.4
        bodyLabel.attributedText = NSAttributedString(
            string: body,
            attributes: [
                .paragraphStyle: style,
                .font: DSKitFontFamily.Pretendard.regular.font(size: 13),
                .foregroundColor: DSColor.textSecondary
            ]
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DSCard") {
    let card = DSCard(title: "카드 제목", body: "카드 본문 내용이 들어갑니다.")
    card.setActions([SecondaryButton(title: "취소"), PrimaryButton(title: "확인")])
    card.widthAnchor.constraint(equalToConstant: 320).isActive = true
    return card
}
#endif
