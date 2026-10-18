import UIKit

open class BaseButton: UIButton {

    var config = UIButton.Configuration.plain()
    var title = AttributedString("")

    /// 볼록 면(V2.1.0). 면이 있는 버튼만 `installSurface`로 붙인다.
    private(set) var surface: DSSurfaceView?

    public init(title: String = "") {
        super.init(frame: .zero)
        configure(title: title)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func configure(title: String) {}
}

// MARK: - Surface

extension BaseButton {

    /// 볼록 버튼 공통 — 면을 깔고, 눌림 · 비활성 모양을 붙인다.
    /// 비활성은 면을 Neutral200 평면으로, 글자를 textTertiary로 바꾼다.
    func applyRaised(_ spec: DSSurfaceSpec, foreground: UIColor, title: String) {
        config = UIButton.Configuration.plain()
        config.baseForegroundColor = foreground
        config.cornerStyle = .fixed
        config.background.cornerRadius = DSRadius.md
        config.background.backgroundColor = .clear
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
        config.imagePadding = 6
        // 폭이 모자라도 글자 단위로 줄바꿈하지 않고 한 줄로 둔다.
        config.titleLineBreakMode = .byTruncatingTail
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)

        self.title = AttributedString(title)
        self.title.font = DSKitFontFamily.Pretendard.semiBold.font(size: 16)
        config.attributedTitle = self.title
        configuration = config

        installSurface(spec)

        configurationUpdateHandler = { [weak self] button in
            guard let self, var updated = button.configuration else { return }
            let isDisabled = button.state.contains(.disabled)
            updated.baseForegroundColor = isDisabled ? DSColor.textTertiary : foreground
            self.surface?.spec = isDisabled ? .flat(DSColor.Neutral._200) : spec
            self.surface?.alpha = button.isHighlighted ? 0.85 : 1
            button.configuration = updated
        }
    }

    private func installSurface(_ spec: DSSurfaceSpec) {
        surface?.removeFromSuperview()
        let surface = DSSurfaceView(spec: spec, cornerRadius: config.background.cornerRadius)
        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(surface, at: 0)
        self.surface = surface
    }
}

// MARK: - Methods

extension BaseButton {
    /// 버튼의 enable 여부 설정
    @discardableResult
    public func setEnabled(_ isEnabled: Bool) -> Self {
        self.isEnabled = isEnabled
        return self
    }

    /// 버튼의 text 설정
    @discardableResult
    public func setTitle(_ title: String) -> Self {
        let font = self.title.font
        self.title = AttributedString(title)
        self.title.font = font
        config.attributedTitle = self.title
        configuration = config
        return self
    }

    /// 제목 앞 아이콘. nil이면 뺀다.
    @discardableResult
    public func setIcon(_ icon: DSIcon?) -> Self {
        config.image = icon?.uiImage.resized(to: CGSize(width: 18, height: 18))
        configuration = config
        return self
    }

    /// content의 edge 변경
    @discardableResult
    public func changeInset(
        top: CGFloat = 0,
        leading: CGFloat = 0,
        bottom: CGFloat = 0,
        trailing: CGFloat = 0
    ) -> Self {
        config.contentInsets = NSDirectionalEdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
        self.configuration = config
        return self
    }

    /// 버튼의 cornerRadius 변경
    @discardableResult
    public func changeCornerRadius(radius: Double) -> Self {
        config.background.cornerRadius = radius
        self.configuration = config
        surface?.cornerRadius = radius
        return self
    }

    /// 캡슐 모양 — 하단 바의 주 버튼(`DSBottomBar`)
    @discardableResult
    public func setCapsule() -> Self {
        config.cornerStyle = .capsule
        self.configuration = config
        surface?.cornerRadius = nil
        return self
    }
}

// MARK: - Image

extension UIImage {

    /// 템플릿 렌더링을 유지한 채 크기만 바꾼다 — 아이콘 에셋이 24pt 기준이라 버튼 안 크기에 맞춘다.
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        .withRenderingMode(.alwaysTemplate)
    }
}
