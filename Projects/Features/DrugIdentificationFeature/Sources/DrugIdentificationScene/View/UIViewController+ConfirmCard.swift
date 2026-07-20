import UIKit
import SnapKit
import Then
import DSKit

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
        let dim = UIView(frame: view.bounds).then {
            $0.backgroundColor = DSColor.Neutral._900.withAlphaComponent(0.6)
            $0.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }

        if dismissOnBackgroundTap {
            let tap = UITapGestureRecognizer(target: dim, action: #selector(UIView.removeFromSuperview))
            dim.addGestureRecognizer(tap)
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
