import UIKit
import SnapKit
import Then
import DSKit

/// 확인 카드 뒤에 까는 dim 배경.
///
/// 배경 탭 닫기를 제스처로 달면 카드 안 버튼(`UIControl`)의 터치까지 가로채
/// 확인 액션이 삼켜진다. 그래서 hit-test 뷰가 자기 자신일 때 —
/// 즉 카드 바깥 빈 배경을 탭했을 때만 닫는다.
private final class ConfirmDimView: UIView {

    var onBackgroundTap: (() -> Void)?

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let touch = touches.first, touch.view === self else { return }
        onBackgroundTap?()
    }
}

extension UIViewController {

    /// 확인 카드를 dim 위에 가운데 정렬로 띄운다.
    ///
    /// - Parameter dismissOnBackgroundTap: 되돌릴 수 없는 동작은 `false`로 둔다 —
    ///   배경 탭으로 닫히면 실수로 흘려보내기 쉽다.
    func presentConfirmCard(
        _ card: ConfirmCardView,
        dismissOnBackgroundTap: Bool,
        confirmed: @escaping () -> Void
    ) {
        let dim = ConfirmDimView(frame: view.bounds).then {
            $0.backgroundColor = DSColor.Neutral._900.withAlphaComponent(0.6)
            $0.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }

        if dismissOnBackgroundTap {
            dim.onBackgroundTap = { [weak dim] in dim?.removeFromSuperview() }
        }

        card.onCancel = { dim.removeFromSuperview() }
        card.onConfirm = {
            dim.removeFromSuperview()
            confirmed()
        }

        dim.addSubview(card)
        view.addSubview(dim)
        card.snp.makeConstraints { $0.center.equalToSuperview() }
    }

    /// 식별 중단 확인 팝업. 화면마다 잃는 것이 달라 문구를 받는다.
    func presentExitConfirm(title: String, message: String? = nil, confirmed: @escaping () -> Void) {
        let card = ConfirmCardView(
            title: title,
            message: message,
            cancelTitle: "계속하기",
            confirmTitle: "나가기",
            isDestructive: true
        )
        presentConfirmCard(card, dismissOnBackgroundTap: false, confirmed: confirmed)
    }
}
