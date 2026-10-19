import UIKit


// MARK: - Primary Button
// V2.1.0 볼록 · 파랑: 면 raised-primary(위→아래 그러데이션), 흰색 텍스트, SemiBold 16, cornerRadius 12, padding(14, 24)
// 비활성: Neutral200 평면 + textTertiary 텍스트

public final class PrimaryButton: BaseButton {

    override public func configure(title: String) {
        applyRaised(.raisedPrimary, foreground: .white, title: title)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("PrimaryButton") {
    PrimaryButton(title: "확인")
}
#endif
