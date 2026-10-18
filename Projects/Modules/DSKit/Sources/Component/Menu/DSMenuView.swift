import UIKit

// MARK: - Menu
// V2.1.0 평면 더보기 메뉴(`kZaQ3`): 폭 160, surface, cornerRadius 12, 테두리 Border 1px, 목록 그림자
// Item: 높이 44, padding (0, 14), gap 10, 아이콘 18 + Label Medium 14, 항목 사이 Neutral100 1px 구분선
// destructive 항목은 아이콘 · 글자 모두 Error600
// 띄우는 위치와 바깥 탭으로 닫기는 화면이 맡는다.

public final class DSMenuView: UIView {

    public struct Item {
        public let icon: DSIcon
        public let title: String
        public let isDestructive: Bool
        public let handler: () -> Void

        public init(icon: DSIcon, title: String, isDestructive: Bool = false, handler: @escaping () -> Void) {
            self.icon = icon
            self.title = title
            self.isDestructive = isDestructive
            self.handler = handler
        }
    }

    // MARK: - Properties

    private let items: [Item]
    private let surface = DSSurfaceView(
        spec: DSSurfaceSpec(
            fills: [.solid(DSColor.surface)],
            stroke: .solid(DSColor.border),
            shadows: [DSMaterialToken.shadowList, DSMaterialToken.shadowListContact]
        ),
        cornerRadius: DSRadius.md
    )

    // MARK: - Init

    public init(items: [Item]) {
        self.items = items
        super.init(frame: .zero)
        setupUI()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(surface)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false

        for (index, item) in items.enumerated() {
            stack.addArrangedSubview(makeRow(item, index: index))
            if index < items.count - 1 {
                let divider = UIView()
                divider.backgroundColor = DSColor.Neutral._100
                divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
                stack.addArrangedSubview(divider)
            }
        }

        addSubview(stack)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 160),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func makeRow(_ item: Item, index: Int) -> UIButton {
        let color = item.isDestructive ? DSColor.Error._600 : DSColor.textPrimary

        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = color
        config.image = item.icon.uiImage.resized(to: CGSize(width: 18, height: 18))
        config.imagePadding = 10
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14)
        var title = AttributedString(item.title)
        title.font = DSKitFontFamily.Pretendard.medium.font(size: 14)
        config.attributedTitle = title

        let button = UIButton(configuration: config)
        button.contentHorizontalAlignment = .leading
        button.tag = index
        button.addTarget(self, action: #selector(itemTapped), for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }

    @objc private func itemTapped(_ sender: UIButton) {
        items[sender.tag].handler()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DSMenuView") {
    DSMenuView(items: [
        .init(icon: .pencil, title: "수정") {},
        .init(icon: .trash, title: "삭제", isDestructive: true) {}
    ])
}
#endif
