import UIKit

// MARK: - List Row
// 배경 white, cornerRadius 14, shadow(#1E293B 4%, y:1, blur:6)
// padding (14, 16), gap 12, horizontal center
// 좌: 40x40 iconBg(Info50, r10) + icon 20x20(Info500)
// 중: Title SemiBold 14 textPrimary + Subtitle Regular 12 Neutral400
// 우: chevron-right 18x18 Neutral400

public final class DSListRow: UIView {

    // MARK: - UI

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.tintColor = DSColor.Info._500
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iv.widthAnchor.constraint(equalToConstant: 20),
            iv.heightAnchor.constraint(equalToConstant: 20)
        ])
        return iv
    }()

    private let iconBackground: UIView = {
        let view = UIView()
        view.backgroundColor = DSColor.Info._50
        view.layer.cornerRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 40),
            view.heightAnchor.constraint(equalToConstant: 40)
        ])
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = DSKitFontFamily.Pretendard.semiBold.font(size: 14)
        label.textColor = DSColor.textPrimary
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
        label.textColor = DSColor.Neutral._400
        return label
    }()

    private let chevronView: UIImageView = {
        let iv = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
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
        subtitleLabel.text = subtitle
        setupUI()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .white
        layer.cornerRadius = 14
        layer.shadowColor = DSColor.textPrimary.cgColor
        layer.shadowOpacity = 0.04
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 3

        iconBackground.addSubview(iconImageView)
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor)
        ])

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        chevronView.setContentHuggingPriority(.required, for: .horizontal)
        chevronView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let rowStack = UIStackView(arrangedSubviews: [iconBackground, textStack, chevronView])
        rowStack.axis = .horizontal
        rowStack.spacing = 12
        rowStack.alignment = .center
        rowStack.distribution = .fill
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }
}

// MARK: - Methods

extension DSListRow {

    public func setTitle(_ title: String) {
        titleLabel.text = title
    }

    public func setSubtitle(_ subtitle: String) {
        subtitleLabel.text = subtitle
    }

    public func setIcon(_ icon: DSIcon) {
        iconImageView.image = icon.uiImage
    }

    public func setChevronHidden(_ hidden: Bool) {
        chevronView.isHidden = hidden
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
