import UIKit

// MARK: - Text Button
// 배경 투명, 텍스트 Primary600, SemiBold 15, cornerRadius 12, padding(14, 16)

public final class TextButton: BaseButton {

    override public func configure(title: String) {
        config = UIButton.Configuration.plain()
        config.baseForegroundColor = DSColor.Primary._600
        config.cornerStyle = .fixed
        config.background.cornerRadius = DSRadius.md
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 14, leading: 16, bottom: 14, trailing: 16
        )

        self.title = AttributedString(title)
        self.title.font = DSKitFontFamily.Pretendard.semiBold.font(size: 15)
        config.attributedTitle = self.title

        configuration = config
    }
}

#if DEBUG
#Preview("TextButton") {
    TextButton(title: "텍스트 버튼")
}
#endif
