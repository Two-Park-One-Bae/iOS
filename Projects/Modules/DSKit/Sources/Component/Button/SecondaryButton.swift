import UIKit

// MARK: - Secondary Button
// V2.1.0 볼록 · 흰색: 면 surface→raised-neutral-bottom, 테두리 Neutral200 1px, 텍스트 TextPrimary, SemiBold 16, cornerRadius 12, padding(14, 24)

public final class SecondaryButton: BaseButton {

    override public func configure(title: String) {
        applyRaised(.raisedNeutral(), foreground: DSColor.textPrimary, title: title)
    }
}

#if DEBUG
#Preview("SecondaryButton") {
    SecondaryButton(title: "확인")
}
#endif
