import UIKit

// MARK: - Text Field
// Label: Pretendard Medium 13 textSecondary, gap 6
// Field: white bg, cornerRadius 12, stroke Neutral200 1px, padding (14, 16)
// Placeholder: Pretendard Regular 15 Neutral400

public final class DSTextField: UIView {

    // MARK: - UI

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = DSKitFontFamily.Pretendard.medium.font(size: 13)
        label.textColor = DSColor.textSecondary
        return label
    }()

    public let textField: UITextField = {
        let tf = UITextField()
        tf.font = DSKitFontFamily.Pretendard.regular.font(size: 15)
        tf.textColor = DSColor.textPrimary
        tf.backgroundColor = .white
        tf.layer.cornerRadius = 12
        tf.layer.borderColor = DSColor.Neutral._200.cgColor
        tf.layer.borderWidth = 1
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        tf.leftViewMode = .always
        tf.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        tf.rightViewMode = .always
        tf.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tf.heightAnchor.constraint(equalToConstant: 48)
        ])
        return tf
    }()

    // MARK: - Init

    public init(label: String, placeholder: String) {
        super.init(frame: .zero)
        titleLabel.text = label
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: DSColor.Neutral._400,
                .font: DSKitFontFamily.Pretendard.regular.font(size: 15)
            ]
        )
        setupUI()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        let stack = UIStackView(arrangedSubviews: [titleLabel, textField])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

// MARK: - Methods

extension DSTextField {

    public func setLabel(_ text: String) {
        titleLabel.text = text
    }

    public func setPlaceholder(_ text: String) {
        textField.attributedPlaceholder = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: DSColor.Neutral._400,
                .font: DSKitFontFamily.Pretendard.regular.font(size: 15)
            ]
        )
    }

    public var text: String? {
        get { textField.text }
        set { textField.text = newValue }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DSTextField") {
    let field = DSTextField(label: "라벨", placeholder: "입력하세요")
    field.widthAnchor.constraint(equalToConstant: 320).isActive = true
    return field
}
#endif
