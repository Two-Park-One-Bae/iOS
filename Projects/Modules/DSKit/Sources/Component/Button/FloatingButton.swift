import UIKit

// MARK: - Floating Button
// V2.1.0 띄운 버튼: 원형 56x56, 파랗게 물든 유리(배경 흐림 + 무지갯빛 테두리 1.2), 흰 아이콘 26
// 그림자 raised-primary-shadow (y 8, blur 20)

public final class FloatingButton: UIButton {

    private let surface = DSSurfaceView(spec: .glassTintPrimary, cornerRadius: nil)

    public init(icon: DSIcon = .plus) {
        super.init(frame: .zero)
        configure(icon: icon)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure(icon: DSIcon) {
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .white
        config.image = icon.uiImage.resized(to: CGSize(width: 26, height: 26))
        config.background.backgroundColor = .clear
        configuration = config

        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(surface, at: 0)

        configurationUpdateHandler = { [weak self] button in
            self?.surface.alpha = button.isHighlighted ? 0.85 : 1
        }

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 56),
            heightAnchor.constraint(equalToConstant: 56)
        ])
    }
}

#if DEBUG
#Preview("FloatingButton") {
    FloatingButton()
}
#endif
