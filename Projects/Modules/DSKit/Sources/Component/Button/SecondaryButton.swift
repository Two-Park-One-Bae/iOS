import UIKit

// MARK: - Secondary Button
// 배경 Neutral100, 테두리 Neutral200 1px, 텍스트 TextPrimary, SemiBold 16, cornerRadius 12, padding(15, 24)

public final class SecondaryButton: BaseButton {

    override public func configure(title: String) {
        config = UIButton.Configuration.filled()
        config.baseBackgroundColor = DSColor.Neutral._100
        config.baseForegroundColor = DSColor.textPrimary
        config.cornerStyle = .fixed
        config.background.cornerRadius = DSRadius.md
        config.background.strokeColor = DSColor.Neutral._200
        config.background.strokeWidth = 1
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 15, leading: 24, bottom: 15, trailing: 24
        )

        self.title = AttributedString(title)
        self.title.font = DSKitFontFamily.Pretendard.semiBold.font(size: 16)
        config.attributedTitle = self.title

        configuration = config
    }
}

#if DEBUG
#Preview("SecondaryButton") {
    SecondaryButton(title: "확인")
}
#endif
