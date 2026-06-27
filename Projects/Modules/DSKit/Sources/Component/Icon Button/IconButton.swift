import UIKit

// MARK: - Icon Button
// 원형 40x40, 배경 Neutral100, 아이콘 22x22 TextPrimary

public final class IconButton: UIButton {

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
        configure(image: icon.uiImage)
    }

    private func configure(image: UIImage?) {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = DSColor.Neutral._100
        config.baseForegroundColor = DSColor.textPrimary
        config.cornerStyle = .capsule
        config.image = image
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: 22, weight: .regular
        )
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 9, leading: 9, bottom: 9, trailing: 9
        )
        configuration = config

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
