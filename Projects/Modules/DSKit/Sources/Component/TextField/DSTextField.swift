import UIKit

// MARK: - Text Field
// V2.1.0 평면 입력 칸
// Label: Pretendard Medium 13 textSecondary, gap 6
// Field: surface bg, cornerRadius 12, padding (13, 14), Value Regular 15
//   기본   — stroke Border 1px,      placeholder textTertiary
//   포커스 — stroke Primary500 1.5px
//   오류   — stroke Error500 1.5px    (`setError(true)`)
//   비활성 — bg Neutral100, 테두리 없음, 글자 textTertiary (`setEnabled(false)`)

public final class DSTextField: UIView {

    // MARK: - Properties

    private var isError = false
    private var isEditingField = false

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
        tf.backgroundColor = DSColor.surface
        tf.layer.cornerRadius = DSRadius.md
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        tf.leftViewMode = .always
        tf.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
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
        setPlaceholder(placeholder)
        setupUI()
        applyState()
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

        textField.addTarget(self, action: #selector(editingDidBegin), for: .editingDidBegin)
        textField.addTarget(self, action: #selector(editingDidEnd), for: .editingDidEnd)
    }

    @objc private func editingDidBegin() {
        isEditingField = true
        applyState()
    }

    @objc private func editingDidEnd() {
        isEditingField = false
        applyState()
    }

    /// 상태 우선순위: 비활성 > 오류 > 포커스 > 기본
    private func applyState() {
        let field = textField
        if !field.isEnabled {
            field.backgroundColor = DSColor.Neutral._100
            field.textColor = DSColor.textTertiary
            field.layer.borderWidth = 0
            return
        }

        field.backgroundColor = DSColor.surface
        field.textColor = DSColor.textPrimary
        if isError {
            field.layer.borderColor = DSColor.Error._500.cgColor
            field.layer.borderWidth = 1.5
        } else if isEditingField {
            field.layer.borderColor = DSColor.Primary._500.cgColor
            field.layer.borderWidth = 1.5
        } else {
            field.layer.borderColor = DSColor.border.cgColor
            field.layer.borderWidth = 1
        }
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
                .foregroundColor: DSColor.textTertiary,
                .font: DSKitFontFamily.Pretendard.regular.font(size: 15)
            ]
        )
    }

    /// 오류 테두리(Error500). 안내 문구는 화면이 따로 둔다.
    public func setError(_ isError: Bool) {
        self.isError = isError
        applyState()
    }

    public func setEnabled(_ isEnabled: Bool) {
        textField.isEnabled = isEnabled
        applyState()
    }

    public var text: String? {
        get { textField.text }
        set { textField.text = newValue }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DSTextField") {
    let normal = DSTextField(label: "라벨", placeholder: "입력하세요")
    let error = DSTextField(label: "라벨", placeholder: "입력하세요")
    error.text = "AST"
    error.setError(true)
    let disabled = DSTextField(label: "라벨", placeholder: "입력하세요")
    disabled.text = "AST"
    disabled.setEnabled(false)

    let stack = UIStackView(arrangedSubviews: [normal, error, disabled])
    stack.axis = .vertical
    stack.spacing = 16
    stack.widthAnchor.constraint(equalToConstant: 320).isActive = true
    return stack
}
#endif
