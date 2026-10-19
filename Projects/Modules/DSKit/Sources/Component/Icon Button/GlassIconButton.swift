import UIKit

// MARK: - Glass Icon Button
// V2.1.0 사진 위 작은 유리 원형 28x28: 반투명 흰 면 + 빛 테두리 1px, 아이콘 14x14 TextPrimary
// 후보 사진의 `크게 보기`처럼 사진 위에 얹는 버튼에 쓴다. 보이는 면보다 터치 영역을 넓힌다(44x44).

public final class GlassIconButton: UIButton {

    private let surface = DSSurfaceView(spec: .glassSmall, cornerRadius: nil)

    public init(icon: DSIcon = .maximize) {
        super.init(frame: .zero)
        configure(icon: icon)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure(icon: DSIcon) {
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = DSColor.textPrimary
        config.background.backgroundColor = .clear
        config.image = icon.uiImage.resized(to: CGSize(width: 14, height: 14))
        config.contentInsets = .zero
        configuration = config

        surface.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(surface, at: 0)

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 44),
            heightAnchor.constraint(equalToConstant: 44),
            surface.widthAnchor.constraint(equalToConstant: 28),
            surface.heightAnchor.constraint(equalToConstant: 28),
            surface.centerXAnchor.constraint(equalTo: centerXAnchor),
            surface.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

#if DEBUG
#Preview("GlassIconButton") {
    GlassIconButton()
}
#endif
