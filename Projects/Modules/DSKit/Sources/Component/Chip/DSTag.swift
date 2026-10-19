import UIKit

// MARK: - Tag
// V2.1.0 평면 · 작은 분류 꼬리표. cornerRadius 8, padding (3, 8), Label Medium 11
// secondary(teal): 배경 Secondary50, 글자 Secondary700 — 처치
// info(파랑):      배경 Info50,      글자 Info700      — 검사

public final class DSTag: UIView {

    public enum Style {
        case secondary
        case info

        var background: UIColor {
            switch self {
            case .secondary: return DSColor.Secondary._50
            case .info:      return DSColor.Info._50
            }
        }

        var label: UIColor {
            switch self {
            case .secondary: return DSColor.Secondary._700
            case .info:      return DSColor.Info._700
            }
        }
    }

    // MARK: - UI

    private let label: UILabel = {
        let label = UILabel()
        label.font = DSKitFontFamily.Pretendard.medium.font(size: 11)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Init

    public init(text: String, style: Style = .secondary) {
        super.init(frame: .zero)
        label.text = text
        setupUI()
        setStyle(style)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        layer.cornerRadius = DSRadius.sm
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3)
        ])
    }
}

// MARK: - Methods

extension DSTag {

    public func setText(_ text: String) {
        label.text = text
    }

    public func setStyle(_ style: Style) {
        backgroundColor = style.background
        label.textColor = style.label
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DSTag") {
    let stack = UIStackView(arrangedSubviews: [
        DSTag(text: "처치"),
        DSTag(text: "검사", style: .info)
    ])
    stack.axis = .horizontal
    stack.spacing = 8
    return stack
}
#endif
