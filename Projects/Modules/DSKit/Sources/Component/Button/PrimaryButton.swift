import UIKit


// MARK: - Primary Button
// 디자인: 배경 Primary500, 흰색 텍스트, SemiBold 16, cornerRadius 12, padding(15, 24)

public final class PrimaryButton: BaseButton {

    override public func configure(title: String) {
        config = UIButton.Configuration.filled()
        config.baseBackgroundColor = DSColor.Primary._500
        config.baseForegroundColor = .white
        config.cornerStyle = .fixed
        config.background.cornerRadius = DSRadius.md
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 15, leading: 24, bottom: 15, trailing: 24
        )

        self.title = AttributedString(title)
        self.title.font = DSKitFontFamily.Pretendard.semiBold.font(size: 16)
        config.attributedTitle = self.title

        configuration = config
    }
}

// MARK: - Preview

#if DEBUG
#Preview("PrimaryButton") {
    PrimaryButton(title: "확인")
}
#endif
