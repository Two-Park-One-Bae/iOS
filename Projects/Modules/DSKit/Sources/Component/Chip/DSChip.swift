import UIKit

// MARK: - Chip Style
// 칩의 배경/테두리/강조(dot·아이콘)/라벨 색 묶음. 기본 info(파랑), secondary(teal) 프리셋 제공.

public struct DSChipStyle {

    public let background: UIColor
    public let border: UIColor
    /// dot ring 또는 아이콘 tint.
    public let accent: UIColor
    public let label: UIColor

    public init(background: UIColor, border: UIColor, accent: UIColor, label: UIColor) {
        self.background = background
        self.border = border
        self.accent = accent
        self.label = label
    }

    public static let info = DSChipStyle(
        background: DSColor.Info._50,
        border: DSColor.Info._100,
        accent: DSColor.Info._500,
        label: DSColor.Info._600
    )

    public static let secondary = DSChipStyle(
        background: DSColor.Secondary._50,
        border: DSColor.Secondary._100,
        accent: DSColor.Secondary._500,
        label: DSColor.Secondary._600
    )
}

// MARK: - Chip
// 배경 style.background, stroke style.border 1px, cornerRadius 20 (pill)
// padding (8, 14), gap 6
// 좌측: icon 지정 시 14x14 아이콘(accent tint), 아니면 14x14 dot ring(accent). Label Medium 13 (label)

public final class DSChip: UIView {

    // MARK: - UI

    /// 좌측 요소 — icon이 있으면 아이콘, 없으면 dot ring.
    private let leadingView: UIView

    private let label: UILabel = {
        let label = UILabel()
        label.font = DSKitFontFamily.Pretendard.medium.font(size: 13)
        return label
    }()

    // MARK: - Init

    /// - Parameters:
    ///   - text: 라벨 텍스트
    ///   - icon: 좌측 아이콘. 지정하면 dot 대신 아이콘을 그린다.
    ///   - showDot: icon이 nil일 때만 유효 — dot ring 표시 여부.
    ///   - style: 색 스타일(기본 info).
    public init(text: String, icon: DSIcon? = nil, showDot: Bool = true, style: DSChipStyle = .info) {
        self.leadingView = DSChip.makeLeadingView(icon: icon, showDot: showDot, style: style)
        super.init(frame: .zero)
        label.text = text
        label.textColor = style.label
        setupUI(style: style)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private static func makeLeadingView(icon: DSIcon?, showDot: Bool, style: DSChipStyle) -> UIView {
        let view: UIView
        if let icon {
            let imageView = UIImageView(image: icon.uiImage)
            imageView.tintColor = style.accent
            imageView.contentMode = .scaleAspectFit
            view = imageView
        } else {
            let dot = UIView()
            dot.backgroundColor = .clear
            dot.layer.cornerRadius = 7
            dot.layer.borderWidth = 1.5
            dot.layer.borderColor = style.accent.cgColor
            dot.isHidden = !showDot
            view = dot
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 14),
            view.heightAnchor.constraint(equalToConstant: 14)
        ])
        return view
    }

    private func setupUI(style: DSChipStyle) {
        backgroundColor = style.background
        layer.cornerRadius = 20
        layer.borderColor = style.border.cgColor
        layer.borderWidth = 1

        let stack = UIStackView(arrangedSubviews: [leadingView, label])
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
}

// MARK: - Methods

extension DSChip {

    public func setText(_ text: String) {
        label.text = text
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DSChip") {
    let stack = UIStackView(arrangedSubviews: [
        DSChip(text: "라벨"),
        DSChip(text: "활성 타이머 2", icon: .timer, style: .secondary),
        DSChip(text: "분류", showDot: false)
    ])
    stack.axis = .vertical
    stack.spacing = 8
    stack.alignment = .leading
    return stack
}
#endif
