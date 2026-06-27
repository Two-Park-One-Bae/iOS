import UIKit

// MARK: - Banner
// Warning 스타일: bg Warning100, stroke Warning200, icon Warning600, text Warning700
// cornerRadius 12, padding (12, 14), gap 10, horizontal center
// Icon: 18x18, Text: Pretendard Medium 13, lineHeight 1.4

public final class DSBanner: UIView {

    // MARK: - Style

    public enum Style {
        case info
        case success
        case warning
        case error

        var backgroundColor: UIColor {
            switch self {
            case .info:    return DSColor.Info._50
            case .success: return DSColor.Success._50
            case .warning: return DSColor.Warning._50
            case .error:   return DSColor.Error._50
            }
        }

        var borderColor: UIColor {
            switch self {
            case .info:    return DSColor.Info._100
            case .success: return DSColor.Success._100
            case .warning: return DSColor.Warning._100
            case .error:   return DSColor.Error._100
            }
        }

        var iconColor: UIColor {
            switch self {
            case .info:    return DSColor.Info._500
            case .success: return DSColor.Success._500
            case .warning: return DSColor.Warning._600
            case .error:   return DSColor.Error._500
            }
        }

        var textColor: UIColor {
            switch self {
            case .info:    return DSColor.Info._600
            case .success: return DSColor.Success._600
            case .warning: return DSColor.Warning._700
            case .error:   return DSColor.Error._600
            }
        }

        var systemIcon: String {
            switch self {
            case .info:    return "info.circle"
            case .success: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .error:   return "xmark.circle"
            }
        }
    }

    // MARK: - UI

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iv.widthAnchor.constraint(equalToConstant: 18),
            iv.heightAnchor.constraint(equalToConstant: 18)
        ])
        return iv
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = DSKitFontFamily.Pretendard.medium.font(size: 13)
        label.numberOfLines = 0
        return label
    }()

    // MARK: - Init

    public init(message: String, style: Style = .warning) {
        super.init(frame: .zero)
        setupUI()
        apply(style: style)
        setMessage(message)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        layer.cornerRadius = 12

        messageLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [iconView, messageLabel])
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    private func apply(style: Style) {
        backgroundColor = style.backgroundColor
        layer.borderColor = style.borderColor.cgColor
        layer.borderWidth = 1
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        iconView.image = UIImage(systemName: style.systemIcon, withConfiguration: config)
        iconView.tintColor = style.iconColor
        messageLabel.textColor = style.textColor
    }
}

// MARK: - Methods

extension DSBanner {

    public func setMessage(_ message: String) {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.4
        messageLabel.attributedText = NSAttributedString(
            string: message,
            attributes: [
                .paragraphStyle: style,
                .font: DSKitFontFamily.Pretendard.medium.font(size: 13),
                .foregroundColor: messageLabel.textColor ?? DSColor.Warning._700
            ]
        )
    }

    public func setStyle(_ style: Style) {
        apply(style: style)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DSBanner") {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false

    let warning = DSBanner(message: "안내 메시지가 여기에 표시됩니다.", style: .warning)
    let info = DSBanner(message: "정보 메시지입니다.", style: .info)
    let success = DSBanner(message: "성공 메시지입니다.", style: .success)
    let error = DSBanner(message: "오류 메시지입니다.", style: .error)

    for banner in [warning, info, success, error] {
        banner.widthAnchor.constraint(equalToConstant: 360).isActive = true
        stack.addArrangedSubview(banner)
    }
    return stack
}
#endif
