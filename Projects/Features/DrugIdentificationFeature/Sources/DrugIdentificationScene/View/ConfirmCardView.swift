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

    /// V2.1.0 Modal(`uAIlL`) — 유리 판(r24) · padding 20 · 제목 SemiBold 16, 볼록 버튼 두 개(gap 8).
    private func setup(
        title: String,
        message: String?,
        cancelTitle: String,
        confirmTitle: String,
        isDestructive: Bool
    ) {
        let surface = DSSurfaceView(spec: .glassModal, cornerRadius: DSRadius.xl)
        addSubview(surface)
        surface.snp.makeConstraints { $0.edges.equalToSuperview() }

        snp.makeConstraints { $0.width.equalTo(300) }

        let titleLabel = UILabel().then {
            $0.text = title
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 16)
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

        let cancelButton = SecondaryButton(title: cancelTitle)
        let confirmButton: BaseButton = isDestructive
            ? DestructiveButton(title: confirmTitle)
            : PrimaryButton(title: confirmTitle)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        let buttonsRow = UIStackView(arrangedSubviews: [cancelButton, confirmButton]).then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.distribution = .fillEqually
        }
        buttonsRow.snp.makeConstraints { $0.height.equalTo(48) }

        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, buttonsRow]).then {
            $0.axis = .vertical
            $0.spacing = 6
            $0.alignment = .fill
        }
        // 버튼 위는 16 — 메시지가 없으면 제목 바로 아래.
        stack.setCustomSpacing(message == nil ? 16 : 6, after: titleLabel)
        stack.setCustomSpacing(16, after: messageLabel)

        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(20) }
    }

    @objc private func cancelTapped() { onCancel?() }
    @objc private func confirmTapped() { onConfirm?() }
}
