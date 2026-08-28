//
//  DSConfirmDialogView.swift
//  DSKit
//
//  Created by 바견규 on 8/28/26.
//

import UIKit
import SnapKit
import Then

/// 확인 2버튼 다이얼로그 (취소 + 실행).
///
/// 되돌릴 수 없거나 흐름을 끊는 선택 앞에 세운다 — 로그아웃·계정 삭제·동의 취소가 전부 같은 모양이다
/// (디자인: DESIGN.pen `zFi8P` · `jdS6i` · `Kf67G`).
/// 선택지가 없는 단순 안내에는 `DSAlertCardView`(1버튼)를 쓴다.
public final class DSConfirmDialogView: UIView {

    /// 실행 버튼의 톤. 되돌릴 수 없는 삭제만 destructive 다.
    public enum ConfirmStyle {
        case primary
        case destructive

        var backgroundColor: UIColor {
            switch self {
            case .primary:     return DSColor.Primary._500
            case .destructive: return DSColor.Error._500
            }
        }
    }

    public var onConfirm: (() -> Void)?
    public var onCancel: (() -> Void)?

    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let confirmButton = UIButton(type: .system)

    public init(
        title: String,
        message: String?,
        confirmTitle: String,
        cancelTitle: String = "취소",
        confirmStyle: ConfirmStyle = .primary
    ) {
        super.init(frame: .zero)
        setup(title: title, message: message, confirmTitle: confirmTitle, cancelTitle: cancelTitle, confirmStyle: confirmStyle)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(
        title: String,
        message: String?,
        confirmTitle: String,
        cancelTitle: String,
        confirmStyle: ConfirmStyle
    ) {
        backgroundColor = DSColor.surface
        layer.cornerRadius = DSRadius.lg
        layer.masksToBounds = false

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 24

        snp.makeConstraints { $0.width.equalTo(300) }

        titleLabel.do {
            $0.text = title
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 16)
            $0.textColor = DSColor.textPrimary
            $0.textAlignment = .center
            $0.numberOfLines = 0
        }

        messageLabel.do {
            $0.text = message
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 12)
            $0.textColor = DSColor.textSecondary
            $0.textAlignment = .center
            $0.numberOfLines = 0
            $0.isHidden = (message == nil)
        }

        configure(cancelButton, title: cancelTitle, background: DSColor.Neutral._100, foreground: DSColor.textPrimary)
        configure(confirmButton, title: confirmTitle, background: confirmStyle.backgroundColor, foreground: .white)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [cancelButton, confirmButton]).then {
            $0.axis = .horizontal
            $0.spacing = 10
            $0.distribution = .fillEqually
        }
        buttons.snp.makeConstraints { $0.height.equalTo(48) }

        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, buttons]).then {
            $0.axis = .vertical
            $0.spacing = 6
            $0.alignment = .fill
        }
        // 메시지가 없으면 제목 바로 아래에 버튼이 붙으므로 간격을 따로 준다(디자인: 메시지 유/무 22 · 16).
        stack.setCustomSpacing(message == nil ? 16 : 22, after: messageLabel)

        addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().inset(22)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalToSuperview().inset(16)
        }
    }

    private func configure(_ button: UIButton, title: String, background: UIColor, foreground: UIColor) {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = background
        config.baseForegroundColor = foreground
        config.cornerStyle = .fixed
        config.background.cornerRadius = DSRadius.md

        var attributed = AttributedString(title)
        attributed.font = DSKitFontFamily.Pretendard.semiBold.font(size: 15)
        config.attributedTitle = attributed

        button.configuration = config
    }

    @objc private func cancelTapped() { onCancel?() }
    @objc private func confirmTapped() { onConfirm?() }

    // MARK: - Present

    /// dim 위에 가운데 정렬로 띄운다. 배경 탭으로는 닫히지 않는다 — 둘 중 하나를 반드시 고르게 한다.
    ///
    /// dim 제거는 자동이므로 콜백에는 후속 동작만 넣으면 된다.
    @discardableResult
    public static func present(
        on parent: UIView,
        title: String,
        message: String? = nil,
        confirmTitle: String,
        cancelTitle: String = "취소",
        confirmStyle: ConfirmStyle = .primary,
        confirmed: @escaping () -> Void,
        cancelled: (() -> Void)? = nil
    ) -> DSConfirmDialogView {
        let dialog = DSConfirmDialogView(
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            cancelTitle: cancelTitle,
            confirmStyle: confirmStyle
        )

        let dim = UIView(frame: parent.bounds).then {
            $0.backgroundColor = DSColor.Neutral._900.withAlphaComponent(0.6)
            $0.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }

        dialog.onConfirm = { [weak dim] in
            dim?.removeFromSuperview()
            confirmed()
        }
        dialog.onCancel = { [weak dim] in
            dim?.removeFromSuperview()
            cancelled?()
        }

        dim.addSubview(dialog)
        parent.addSubview(dim)
        dialog.snp.makeConstraints { $0.center.equalToSuperview() }

        return dialog
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DSConfirmDialogView") {
    DSConfirmDialogView(
        title: "계정을 삭제할까요?",
        message: "삭제하면 되돌릴 수 없어요",
        confirmTitle: "삭제",
        confirmStyle: .destructive
    )
}
#endif
