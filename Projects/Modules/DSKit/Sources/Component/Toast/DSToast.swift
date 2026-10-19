import UIKit
import SnapKit
import Then

// MARK: - Toast
// 하단에 잠깐 떴다 사라지는 알림. 글자 Medium 13 흰색, 배경 textPrimary 90%, cornerRadius 10, padding (10, 16)

public extension UIViewController {

    /// 하단에 잠깐 떴다 사라지는 알림 (확인 버튼 없음).
    /// - Parameter anchor: 이 뷰 바로 위에 띄운다. nil이면 안전 영역 아래쪽.
    func showToast(_ message: String, above anchor: UIView? = nil) {
        let toast = PaddingLabel().then {
            $0.text = message
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 13)
            $0.textColor = DSColor.Neutral._0
            $0.backgroundColor = DSColor.textPrimary.withAlphaComponent(0.9)
            $0.textAlignment = .center
            $0.layer.cornerRadius = 10
            $0.clipsToBounds = true
            $0.alpha = 0
        }
        view.addSubview(toast)
        toast.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            if let anchor {
                $0.bottom.equalTo(anchor.snp.top).offset(-16)
            } else {
                $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-16)
            }
            $0.leading.greaterThanOrEqualToSuperview().offset(40)
            $0.trailing.lessThanOrEqualToSuperview().offset(-40)
        }
        UIView.animate(withDuration: 0.25, animations: { toast.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.25, delay: 1.4, options: []) {
                toast.alpha = 0
            } completion: { _ in toast.removeFromSuperview() }
        }
    }
}

// 토스트용 — 상하좌우 여백이 있는 라벨.
private final class PaddingLabel: UILabel {
    private let inset = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: inset))
    }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + inset.left + inset.right,
                      height: s.height + inset.top + inset.bottom)
    }
}
