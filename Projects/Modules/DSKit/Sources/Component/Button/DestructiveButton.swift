import UIKit

// MARK: - Destructive Button
// V2.1.0 볼록 · 빨강: 면 raised-error, 흰색 텍스트, SemiBold 16, cornerRadius 12, padding(14, 24)
// 되돌릴 수 없는 삭제에만 쓴다.

public final class DestructiveButton: BaseButton {

    override public func configure(title: String) {
        applyRaised(.raisedError, foreground: .white, title: title)
    }
}

#if DEBUG
#Preview("DestructiveButton") {
    DestructiveButton(title: "삭제")
}
#endif
