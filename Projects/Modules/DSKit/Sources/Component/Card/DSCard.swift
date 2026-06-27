import UIKit

// MARK: - Card
// 배경 white, cornerRadius 20, shadow(#1E293B 7%, y:2, blur:12), padding 20, gap 8
// Title: Pretendard SemiBold 16, textPrimary
// Body: Pretendard Regular 13, textSecondary, lineHeight 1.4

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

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
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
        backgroundColor = .white
        layer.cornerRadius = DSRadius.xl
        layer.shadowColor = DSColor.textPrimary.cgColor
        layer.shadowOpacity = 0.07
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(bodyLabel)
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
    card.widthAnchor.constraint(equalToConstant: 320).isActive = true
    return card
}
#endif
