import UIKit

// MARK: - List Row
// 배경 white, cornerRadius 20, shadow(#1E293B 7%, y:2, blur:12)
// padding 20, gap 16, horizontal center
// 좌: 56x56 iconBg(Info50, r16) + icon 28x28(Info500)
// 중: Title SemiBold 16 textPrimary + Subtitle Regular 13 textSecondary(줄바꿈, lineHeight 1.1) + Caption SemiBold 12
// 우: chevron-right 16 Neutral400

public final class DSListRow: UIView {

    // MARK: - UI

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.tintColor = DSColor.Info._500
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iv.widthAnchor.constraint(equalToConstant: 28),
            iv.heightAnchor.constraint(equalToConstant: 28)
        ])
        return iv
    }()

    private let iconBackground: UIView = {
        let view = UIView()
        view.backgroundColor = DSColor.Info._50
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 56),
            view.heightAnchor.constraint(equalToConstant: 56)
        ])
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = DSKitFontFamily.Pretendard.semiBold.font(size: 16)
        label.textColor = DSColor.textPrimary
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
        label.textColor = DSColor.textSecondary
        // 말줄임(...) 대신 줄바꿈 — 디자인의 설명 문구는 카드 폭에서 여러 줄로 흐른다.
        label.numberOfLines = 0
        return label
    }()

    // 부가 상태 한 줄(예: 알약 식별 남은 횟수). 기본 숨김 — 설정한 화면에서만 나타난다.
    private let captionLabel: UILabel = {
        let label = UILabel()
        label.font = DSKitFontFamily.Pretendard.semiBold.font(size: 12)
        label.textColor = DSColor.Primary._600
        label.isHidden = true
        return label
    }()

    private let chevronView: UIImageView = {
        let iv = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        iv.image = UIImage(systemName: "chevron.right", withConfiguration: config)
        iv.tintColor = DSColor.Neutral._400
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // MARK: - Init

    public init(icon: DSIcon, title: String, subtitle: String) {
        super.init(frame: .zero)
        iconImageView.image = icon.uiImage
        titleLabel.text = title
        setSubtitle(subtitle)
        setupUI()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .white
        layer.cornerRadius = 20
        layer.shadowColor = DSColor.textPrimary.cgColor
        layer.shadowOpacity = 0.07
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6

        iconBackground.addSubview(iconImageView)
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor)
        ])

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, captionLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        chevronView.setContentHuggingPriority(.required, for: .horizontal)
        chevronView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let rowStack = UIStackView(arrangedSubviews: [iconBackground, textStack, chevronView])
        rowStack.axis = .horizontal
        rowStack.spacing = 16
        rowStack.alignment = .center
        rowStack.distribution = .fill
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
}

// MARK: - Methods

extension DSListRow {

    public func setTitle(_ title: String) {
        titleLabel.text = title
    }

    public func setSubtitle(_ subtitle: String) {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.1
        subtitleLabel.attributedText = NSAttributedString(
            string: subtitle,
            attributes: [
                .paragraphStyle: style,
                .font: DSKitFontFamily.Pretendard.regular.font(size: 13),
                .foregroundColor: DSColor.textSecondary
            ]
        )
    }

    public func setIcon(_ icon: DSIcon) {
        iconImageView.image = icon.uiImage
    }

    public func setChevronHidden(_ hidden: Bool) {
        chevronView.isHidden = hidden
    }

    /// 부가 상태 한 줄. `nil`이면 숨긴다.
    public func setCaption(_ text: String?, color: UIColor = DSColor.Primary._600) {
        captionLabel.text = text
        captionLabel.textColor = color
        captionLabel.isHidden = (text == nil)
    }

    public func setIconBackground(_ color: UIColor) {
        iconBackground.backgroundColor = color
    }

    public func setIconTint(_ color: UIColor) {
        iconImageView.tintColor = color
    }

    public func onTap(_ handler: @escaping () -> Void) {
        isUserInteractionEnabled = true
        let recognizer = DSListRowTapRecognizer(target: self, action: #selector(handleTap))
        recognizer.handler = handler
        addGestureRecognizer(recognizer)
    }

    @objc private func handleTap(_ recognizer: DSListRowTapRecognizer) {
        recognizer.handler?()
    }
}

// MARK: - Tap Recognizer

private final class DSListRowTapRecognizer: UITapGestureRecognizer {
    var handler: (() -> Void)?
}

// MARK: - Preview

#if DEBUG
#Preview("DSListRow") {
    let row = DSListRow(icon: .heart, title: "항목 제목", subtitle: "부가 설명")
    row.widthAnchor.constraint(equalToConstant: 340).isActive = true
    return row
}
#endif
