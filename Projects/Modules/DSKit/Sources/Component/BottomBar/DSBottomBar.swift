import UIKit

// MARK: - Bottom Bar
// V2.1.0 하단 바(`IkyB0`): 판 없이 버튼과 면책 고지만 탭 바 위에 띄운다 — 유리 판을 한 겹 더 쌓지 않는다.
// padding (10, 20, 6, 20), 세로 gap 8
// Buttons: 캡슐 버튼을 같은 폭으로, gap 10, padding(16, 24)
// Disclaimer(선택): Regular 11 textTertiary, 가운데 정렬, lineHeight 1.4

public final class DSBottomBar: UIView {

    // MARK: - UI

    private let buttonStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.distribution = .fillEqually
        return stack
    }()

    private let disclaimerLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    // MARK: - Init

    public init(buttons: [BaseButton], disclaimer: String? = nil) {
        super.init(frame: .zero)
        setupUI()
        setButtons(buttons)
        setDisclaimer(disclaimer)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        let stack = UIStackView(arrangedSubviews: [buttonStack, disclaimerLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
    }
}

// MARK: - Methods

extension DSBottomBar {

    public func setButtons(_ buttons: [BaseButton]) {
        buttonStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for button in buttons {
            button.setCapsule().changeInset(top: 16, leading: 24, bottom: 16, trailing: 24)
            buttonStack.addArrangedSubview(button)
        }
    }

    /// nil이면 고지 줄을 숨긴다.
    public func setDisclaimer(_ text: String?) {
        guard let text else {
            disclaimerLabel.isHidden = true
            return
        }

        let font = DSKitFontFamily.Pretendard.regular.font(size: 11)
        let style = NSMutableParagraphStyle()
        style.lineSpacing = font.lineHeight * 0.4
        style.alignment = .center
        disclaimerLabel.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .paragraphStyle: style,
                .font: font,
                .foregroundColor: DSColor.textTertiary
            ]
        )
        disclaimerLabel.isHidden = false
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DSBottomBar") {
    let bar = DSBottomBar(
        buttons: [SecondaryButton(title: "공유"), PrimaryButton(title: "완료")],
        disclaimer: "널스메이트의 알약 식별 결과는 참고용 보조 정보입니다."
    )
    bar.widthAnchor.constraint(equalToConstant: 390).isActive = true
    return bar
}
#endif
