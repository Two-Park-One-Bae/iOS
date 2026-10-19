import UIKit

// MARK: - Icon Button
// V2.1.0 볼록 · 흰색 원형 40x40: 면 surface→raised-neutral-bottom, 테두리 Neutral200 1px, 아이콘 20x20 TextPrimary

public final class IconButton: UIButton {

    private let surface = DSSurfaceView(spec: .raisedNeutral(), cornerRadius: nil)

    public init(icon: DSIcon) {
        super.init(frame: .zero)
        configure(icon: icon)
    }

    public init(image: UIImage?) {
        super.init(frame: .zero)
        configure(image: image)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure(icon: DSIcon) {
        configure(image: icon.uiImage.resized(to: CGSize(width: 20, height: 20)))
    }

    private func configure(image: UIImage?) {
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = DSColor.textPrimary
        config.background.backgroundColor = .clear
        config.image = image
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: 17, weight: .semibold
        )
        config.contentInsets = .zero
        configuration = config

        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(surface, at: 0)

        configurationUpdateHandler = { [weak self] button in
            self?.surface.alpha = button.isHighlighted ? 0.85 : 1
        }

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 40),
            heightAnchor.constraint(equalToConstant: 40)
        ])
        translatesAutoresizingMaskIntoConstraints = false
    }
}

#if DEBUG
#Preview("IconButton") {
    IconButton(icon: .xMark)
}
#endif
