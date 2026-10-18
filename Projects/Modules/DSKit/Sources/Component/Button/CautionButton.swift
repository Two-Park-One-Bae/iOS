import UIKit

// MARK: - Caution Button
// V2.1.0 볼록 · 살구: 면 raised-caution, 흰색 텍스트, SemiBold 16, cornerRadius 12, padding(14, 24), 아이콘 18
// 타이머 만료 카드의 `완료`에만 쓴다 — 살구색 카드에서 하나뿐인 동작이라 같은 색으로 강조한다.

public final class CautionButton: BaseButton {

    override public func configure(title: String) {
        applyRaised(.raisedCaution, foreground: .white, title: title)
    }
}

#if DEBUG
#Preview("CautionButton") {
    CautionButton(title: "완료").setIcon(.check)
}
#endif
