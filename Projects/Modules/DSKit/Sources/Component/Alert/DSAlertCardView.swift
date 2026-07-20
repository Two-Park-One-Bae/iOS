//
//  DSAlertCardView.swift
//  DSKit
//
//  Created by 바견규 on 7/20/26.
//

import UIKit
import SnapKit
import Then

/// 확인 1버튼 알럿 카드 (콘텐츠 전용 — dim/positioning은 `present(on:)`가 담당).
///
/// 대안 액션이 없는 안내에 쓴다. 선택지가 있으면 바텀시트나 2버튼 카드를 쓸 것.
public final class DSAlertCardView: UIView {

    public var onConfirm: (() -> Void)?

    private let titleLabel = UILabel()
    private let messageLabel = UILabel()

    public init(title: String, message: String?, confirmTitle: String = "확인") {
        super.init(frame: .zero)
        setup(title: title, message: message, confirmTitle: confirmTitle)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(title: String, message: String?, confirmTitle: String) {
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
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
            $0.textColor = DSColor.textSecondary
            $0.textAlignment = .center
            $0.numberOfLines = 0
            $0.isHidden = (message == nil)
        }

        let confirmButton = PrimaryButton(title: confirmTitle)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        confirmButton.snp.makeConstraints { $0.height.equalTo(48) }

        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, confirmButton]).then {
            $0.axis = .vertical
            $0.spacing = 8
            $0.alignment = .fill
        }
        // 버튼 위쪽 추가 여백
        stack.setCustomSpacing(16, after: messageLabel)

        addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().inset(22)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalToSuperview().inset(16)
        }
    }

    @objc private func confirmTapped() { onConfirm?() }

    /// dim 위에 가운데 정렬로 띄운다. 확인을 눌러야 닫히고, 배경 탭으로는 닫히지 않는다
    /// — 안내를 보지 못한 채 넘어가지 않도록.
    ///
    /// dim 제거는 자동이므로 `confirmed`에는 후속 동작만 넣으면 된다.
    public static func present(
        on parent: UIView,
        title: String,
        message: String?,
        confirmTitle: String = "확인",
        confirmed: (() -> Void)? = nil
    ) {
        let card = DSAlertCardView(title: title, message: message, confirmTitle: confirmTitle)
        let dim = UIView(frame: parent.bounds).then {
            $0.backgroundColor = DSColor.Neutral._900.withAlphaComponent(0.6)
            $0.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }

        card.onConfirm = { [weak dim] in
            dim?.removeFromSuperview()
            confirmed?()
        }

        dim.addSubview(card)
        parent.addSubview(dim)
        card.snp.makeConstraints { $0.center.equalToSuperview() }
    }

    /// 키 윈도우 위에 띄운다 — dim이 탭바까지 덮고, 탭 전환 뒤에도 살아남는다.
    ///
    /// 특정 화면에 종속되지 않는 안내(예: 식별 한도)는 이걸 쓴다.
    /// 화면 안에서만 의미 있는 안내라면 `present(on:)`으로 해당 뷰에 붙일 것.
    public static func presentOverWindow(
        title: String,
        message: String?,
        confirmTitle: String = "확인",
        confirmed: (() -> Void)? = nil
    ) {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }

        // 모달이 떠 있으면 루트 뷰에 붙여봐야 가려진다 — 최상단 표시 중인 뷰컨트롤러를 찾는다.
        // 모달이 없으면 루트(탭바 컨트롤러)라 dim이 탭바까지 덮는다(디자인 기준).
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }

        guard let host = top?.view else { return }

        present(on: host, title: title, message: message, confirmTitle: confirmTitle, confirmed: confirmed)
    }
}
