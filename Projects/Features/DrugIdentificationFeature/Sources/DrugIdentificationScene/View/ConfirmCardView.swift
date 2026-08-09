import UIKit
import SnapKit
import Then
import DSKit

/// 취소/확인 2버튼 확인 다이얼로그 카드 (콘텐츠 전용 — dim/positioning은 호출자 담당).
///
/// 되돌릴 수 없는 동작 앞에서 한 번 확인받는 용도. 안내만 필요하면 확인 1버튼을 쓸 것.
final class ConfirmCardView: UIView {

    var onCancel: (() -> Void)?
    var onConfirm: (() -> Void)?

    /// - Parameters:
    ///   - message: 제목만으로 부족할 때만 쓴다. nil이면 줄 자체가 사라진다.
    ///   - isDestructive: 확인 버튼을 경고색으로 — 삭제처럼 잃는 게 있는 동작에 쓴다.
    init(
        title: String,
        message: String? = nil,
        cancelTitle: String = "취소",
        confirmTitle: String = "확인",
        isDestructive: Bool = false
    ) {
        super.init(frame: .zero)
        setup(
            title: title,
            message: message,
            cancelTitle: cancelTitle,
            confirmTitle: confirmTitle,
            isDestructive: isDestructive
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(
        title: String,
        message: String?,
        cancelTitle: String,
        confirmTitle: String,
        isDestructive: Bool
    ) {
        backgroundColor = DSColor.Neutral._0
        layer.cornerRadius = 16
        layer.masksToBounds = false

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 24

        snp.makeConstraints { $0.width.equalTo(300) }

        let titleLabel = UILabel().then {
            $0.text = title
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 16)
            $0.textColor = DSColor.textPrimary
            $0.textAlignment = .center
            $0.numberOfLines = 0
        }

        let messageLabel = UILabel().then {
            $0.text = message
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
            $0.textColor = DSColor.textSecondary
            $0.textAlignment = .center
            $0.numberOfLines = 0
            $0.isHidden = (message == nil)
        }

        let cancelButton = makeButton(
            title: cancelTitle,
            titleColor: DSColor.textPrimary,
            background: DSColor.Neutral._100,
            action: #selector(cancelTapped)
        )
        let confirmButton = makeButton(
            title: confirmTitle,
            titleColor: DSColor.Neutral._0,
            background: isDestructive ? DSColor.Error._500 : DSColor.Primary._500,
            action: #selector(confirmTapped)
        )
        let buttonsRow = UIStackView(arrangedSubviews: [cancelButton, confirmButton]).then {
            $0.axis = .horizontal
            $0.spacing = 10
            $0.distribution = .fillEqually
        }
        cancelButton.snp.makeConstraints { $0.height.equalTo(48) }
        confirmButton.snp.makeConstraints { $0.height.equalTo(48) }

        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, buttonsRow]).then {
            $0.axis = .vertical
            $0.spacing = 8
            $0.alignment = .center
        }
        // 버튼 행 위쪽에 추가 여백 (top padding 8)
        stack.setCustomSpacing(16, after: messageLabel)

        addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().inset(22)
            $0.leading.equalToSuperview().inset(20)
            $0.trailing.equalToSuperview().inset(20)
            $0.bottom.equalToSuperview().inset(16)
        }
        buttonsRow.snp.makeConstraints { $0.width.equalToSuperview() }
    }

    private func makeButton(
        title: String,
        titleColor: UIColor,
        background: UIColor,
        action: Selector
    ) -> UIControl {
        let button = UIControl().then {
            $0.backgroundColor = background
            $0.layer.cornerRadius = 12
            $0.layer.masksToBounds = true
        }
        let label = UILabel().then {
            $0.text = title
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 16)
            $0.textColor = titleColor
            $0.textAlignment = .center
            $0.isUserInteractionEnabled = false
        }
        button.addSubview(label)
        label.snp.makeConstraints { $0.center.equalToSuperview() }

        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func cancelTapped() { onCancel?() }
    @objc private func confirmTapped() { onConfirm?() }
}
