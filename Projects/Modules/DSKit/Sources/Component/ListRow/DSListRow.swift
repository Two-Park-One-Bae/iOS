import UIKit

// MARK: - List Row
// 아이콘 + 제목/부제 + chevron 한 줄. 두 가지 크기가 있다.
//
// .default (홈 카드)   r20 · padding 20 · gap 16 · iconBg 56(r16)/icon 28 · 제목 16 · 부제 13
// .compact (설정 행)   r14 · padding 14/16 · gap 12 · iconBg 40(r10)/icon 20 · 제목 14 · 부제 12
//   — 디자인: DESIGN.pen `Xoc5z` 계정 섹션

public final class DSListRow: UIView {

    public enum Style {
        case `default`
        case compact

        var cornerRadius: CGFloat { self == .default ? 20 : 14 }
        var verticalPadding: CGFloat { self == .default ? 20 : 14 }
        var horizontalPadding: CGFloat { self == .default ? 20 : 16 }
        var spacing: CGFloat { self == .default ? 16 : 12 }
        var iconBackgroundLength: CGFloat { self == .default ? 56 : 40 }
        var iconBackgroundRadius: CGFloat { self == .default ? 16 : 10 }
        var iconLength: CGFloat { self == .default ? 28 : 20 }
        var chevronSize: CGFloat { self == .default ? 16 : 18 }
        var shadowOpacity: Float { self == .default ? 0.07 : 0.04 }
        var shadowOffset: CGSize { self == .default ? CGSize(width: 0, height: 2) : CGSize(width: 0, height: 1) }

        var titleFont: UIFont {
            DSKitFontFamily.Pretendard.semiBold.font(size: self == .default ? 16 : 14)
        }

        var subtitleFont: UIFont {
            DSKitFontFamily.Pretendard.regular.font(size: self == .default ? 13 : 12)
        }

        var subtitleColor: UIColor {
            self == .default ? DSColor.textSecondary : DSColor.textTertiary
        }
    }

    // MARK: - Properties

    private let style: Style

    // MARK: - UI

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.tintColor = DSColor.Info._500
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let iconBackground: UIView = {
        let view = UIView()
        view.backgroundColor = DSColor.Info._50
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel = UILabel()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
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
        iv.tintColor = DSColor.Neutral._400
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // MARK: - Init

    public init(style: Style = .default, icon: DSIcon, title: String, subtitle: String) {
        self.style = style
        super.init(frame: .zero)
        iconImageView.image = icon.uiImage
        titleLabel.font = style.titleFont
        titleLabel.textColor = DSColor.textPrimary
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
        layer.cornerRadius = style.cornerRadius
        layer.shadowColor = DSColor.textPrimary.cgColor
        layer.shadowOpacity = style.shadowOpacity
        layer.shadowOffset = style.shadowOffset
        layer.shadowRadius = 6

        iconBackground.layer.cornerRadius = style.iconBackgroundRadius
        chevronView.image = UIImage(
            systemName: "chevron.right",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: style.chevronSize, weight: .medium)
        )

        iconBackground.addSubview(iconImageView)
        NSLayoutConstraint.activate([
            iconBackground.widthAnchor.constraint(equalToConstant: style.iconBackgroundLength),
            iconBackground.heightAnchor.constraint(equalToConstant: style.iconBackgroundLength),
            iconImageView.widthAnchor.constraint(equalToConstant: style.iconLength),
            iconImageView.heightAnchor.constraint(equalToConstant: style.iconLength),
            iconImageView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor)
        ])

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, captionLabel])
        textStack.axis = .vertical
        textStack.spacing = style == .default ? 4 : 2
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        chevronView.setContentHuggingPriority(.required, for: .horizontal)
        chevronView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let rowStack = UIStackView(arrangedSubviews: [iconBackground, textStack, chevronView])
        rowStack.axis = .horizontal
        rowStack.spacing = style.spacing
        rowStack.alignment = .center
        rowStack.distribution = .fill
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: topAnchor, constant: style.verticalPadding),
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: style.horizontalPadding),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -style.horizontalPadding),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -style.verticalPadding)
        ])
    }
}

// MARK: - Methods

extension DSListRow {

    public func setTitle(_ title: String) {
        titleLabel.text = title
    }

    /// 제목 색. 파괴적 액션(계정 삭제)만 Error 계열로 바꾼다.
    public func setTitleColor(_ color: UIColor) {
        titleLabel.textColor = color
    }

    /// 빈 문자열이면 줄 자체를 숨긴다 — 부제 없는 행(계정 삭제)에서 빈 줄이 생기지 않게.
    public func setSubtitle(_ subtitle: String) {
        guard !subtitle.isEmpty else {
            subtitleLabel.isHidden = true
            return
        }

        subtitleLabel.isHidden = false
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.1
        subtitleLabel.attributedText = NSAttributedString(
            string: subtitle,
            attributes: [
                .paragraphStyle: paragraph,
                .font: style.subtitleFont,
                .foregroundColor: style.subtitleColor
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
    let stack = UIStackView(arrangedSubviews: [
        DSListRow(icon: .heart, title: "항목 제목", subtitle: "부가 설명"),
        DSListRow(style: .compact, icon: .user, title: "로그아웃", subtitle: "언제든 다시 로그인할 수 있어요"),
    ])
    stack.axis = .vertical
    stack.spacing = 12
    stack.widthAnchor.constraint(equalToConstant: 350).isActive = true
    return stack
}
#endif
