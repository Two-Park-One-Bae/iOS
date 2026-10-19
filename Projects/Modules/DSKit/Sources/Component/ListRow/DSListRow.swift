import UIKit

// MARK: - List Row
// 아이콘 + 제목/부제 + chevron 한 줄. 면은 V2.1.0 유리 목록 카드(glassListCard, r20).
//
// .default (홈 카드)   padding 20 · gap 16 · iconBg 56(r16)/icon 28 · 제목 16 → 부제 13
// .compact (V2.1.0 List Row) padding 16 · gap 12 · icon 24(배경 없음, Neutral700) · 부제 12 → 제목 15 · chevron 20
//   — 디자인: DESIGN.pen `h4TX4` (Component V2.1.0 / List Row). 부제가 제목 위에 온다.

public final class DSListRow: UIView {

    public enum Style {
        case `default`
        case compact

        var verticalPadding: CGFloat { self == .default ? 20 : 16 }
        var horizontalPadding: CGFloat { self == .default ? 20 : 16 }
        var spacing: CGFloat { self == .default ? 16 : 12 }
        var iconBackgroundLength: CGFloat { self == .default ? 56 : 24 }
        var iconBackgroundRadius: CGFloat { self == .default ? 16 : 0 }
        var iconLength: CGFloat { self == .default ? 28 : 24 }
        var chevronLength: CGFloat { self == .default ? 16 : 20 }
        var iconTint: UIColor { self == .default ? DSColor.Info._500 : DSColor.Neutral._700 }
        var iconBackgroundColor: UIColor { self == .default ? DSColor.Info._50 : .clear }
        var chevronTint: UIColor { self == .default ? DSColor.Neutral._400 : DSColor.textSecondary }
        /// V2.1.0 List Row는 부제를 제목 위에 둔다.
        var subtitleFirst: Bool { self == .compact }

        var titleFont: UIFont {
            DSKitFontFamily.Pretendard.semiBold.font(size: self == .default ? 16 : 15)
        }

        var subtitleFont: UIFont {
            DSKitFontFamily.Pretendard.regular.font(size: self == .default ? 13 : 12)
        }

        var subtitleColor: UIColor { DSColor.textSecondary }
    }

    // MARK: - Properties

    private let style: Style

    // MARK: - UI

    private let surface = DSSurfaceView(spec: .glassListCard)

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let iconBackground: UIView = {
        let view = UIView()
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
        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(surface)

        iconImageView.tintColor = style.iconTint
        iconBackground.backgroundColor = style.iconBackgroundColor
        iconBackground.layer.cornerRadius = style.iconBackgroundRadius
        chevronView.image = DSIcon.chevronRight.uiImage
        chevronView.tintColor = style.chevronTint

        iconBackground.addSubview(iconImageView)
        NSLayoutConstraint.activate([
            iconBackground.widthAnchor.constraint(equalToConstant: style.iconBackgroundLength),
            iconBackground.heightAnchor.constraint(equalToConstant: style.iconBackgroundLength),
            iconImageView.widthAnchor.constraint(equalToConstant: style.iconLength),
            iconImageView.heightAnchor.constraint(equalToConstant: style.iconLength),
            iconImageView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: style.chevronLength),
            chevronView.heightAnchor.constraint(equalToConstant: style.chevronLength)
        ])

        let labels = style.subtitleFirst
            ? [subtitleLabel, titleLabel, captionLabel]
            : [titleLabel, subtitleLabel, captionLabel]
        let textStack = UIStackView(arrangedSubviews: labels)
        textStack.axis = .vertical
        textStack.spacing = style == .default ? 4 : 1
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

    /// 아이콘 뒤 둥근 판 색(.default 전용). .compact는 V2.1.0 디자인대로 판 없이 아이콘만 둔다.
    public func setIconBackground(_ color: UIColor) {
        guard style == .default else { return }
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
        DSListRow(style: .compact, icon: .logOut, title: "로그아웃", subtitle: "언제든 다시 로그인할 수 있어요"),
        DSListRow(style: .compact, icon: .fileText, title: "약관 및 동의", subtitle: ""),
    ])
    stack.axis = .vertical
    stack.spacing = 12
    stack.widthAnchor.constraint(equalToConstant: 350).isActive = true
    return stack
}
#endif
