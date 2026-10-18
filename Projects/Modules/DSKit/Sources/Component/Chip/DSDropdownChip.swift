import UIKit

// MARK: - Dropdown Chip
// V2.1.0 볼록 · 누르면 메뉴가 열리는 칩. 높이 30, 캡슐, padding (0, 10, 0, 12), gap 2
// 기본:   면 raised-neutral, 테두리 Neutral200 1px,   Label Medium 13 textPrimary,     ▾ 16 textTertiary
// 확정:   면 raised-neutral, 테두리 Primary500 1.5px, Label SemiBold 13 Primary600,    ▾ 16 Primary500
// 메뉴는 `menu` + `showsMenuAsPrimaryAction`으로 붙인다(UIButton 기본 동작).

public final class DSDropdownChip: UIButton {

    // MARK: - Properties

    /// 값을 고른 상태. 사용자가 값을 확정하면 true로 둔다.
    public var isConfirmed: Bool = false {
        didSet { applyState() }
    }

    private let surface = DSSurfaceView(spec: .raisedNeutral(), cornerRadius: nil)
    private var text: String

    // MARK: - Init

    public init(text: String, isConfirmed: Bool = false) {
        self.text = text
        self.isConfirmed = isConfirmed
        super.init(frame: .zero)
        setupUI()
        applyState()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(surface, at: 0)

        configurationUpdateHandler = { [weak self] button in
            self?.surface.alpha = button.isHighlighted ? 0.85 : 1
        }

        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 30).isActive = true
    }

    private func applyState() {
        surface.spec = isConfirmed
            ? .raisedNeutral(stroke: DSColor.Primary._500, strokeWidth: 1.5)
            : .raisedNeutral()

        var config = UIButton.Configuration.plain()
        config.background.backgroundColor = .clear
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 10)
        config.imagePlacement = .trailing
        config.imagePadding = 2
        config.image = DSIcon.chevronDown.uiImage.resized(to: CGSize(width: 16, height: 16))
        config.imageColorTransformer = UIConfigurationColorTransformer { [isConfirmed] _ in
            isConfirmed ? DSColor.Primary._500 : DSColor.textTertiary
        }

        var title = AttributedString(text)
        title.font = isConfirmed
            ? DSKitFontFamily.Pretendard.semiBold.font(size: 13)
            : DSKitFontFamily.Pretendard.medium.font(size: 13)
        title.foregroundColor = isConfirmed ? DSColor.Primary._600 : DSColor.textPrimary
        config.attributedTitle = title

        configuration = config
    }
}

// MARK: - Methods

extension DSDropdownChip {

    public func setText(_ text: String) {
        self.text = text
        applyState()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DSDropdownChip") {
    let stack = UIStackView(arrangedSubviews: [
        DSDropdownChip(text: "전체"),
        DSDropdownChip(text: "입력", isConfirmed: true)
    ])
    stack.axis = .horizontal
    stack.spacing = 8
    return stack
}
#endif
