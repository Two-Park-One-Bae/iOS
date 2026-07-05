import UIKit
import SnapKit
import Then
import DSKit

// 알약 삭제 확인 다이얼로그 카드 (콘텐츠 전용 — dim/positioning은 호출자 담당)
final class DeleteConfirmCardView: UIView {

    var onCancel: (() -> Void)?
    var onDelete: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        // Card
        backgroundColor = DSColor.Neutral._0
        layer.cornerRadius = 16
        layer.masksToBounds = false

        // Shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 24

        snp.makeConstraints { $0.width.equalTo(300) }

        // Title
        let title = UILabel().then {
            $0.text = "이 알약을 삭제할까요?"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 16)
            $0.textColor = DSColor.textPrimary
            $0.textAlignment = .center
            $0.numberOfLines = 0
        }

        // Buttons
        let cancelButton = makeButton(
            title: "취소",
            titleColor: DSColor.textPrimary,
            background: DSColor.Neutral._100,
            action: #selector(cancelTapped)
        )
        let deleteButton = makeButton(
            title: "삭제",
            titleColor: DSColor.Neutral._0,
            background: DSColor.Error._500,
            action: #selector(deleteTapped)
        )
        let buttonsRow = UIStackView(arrangedSubviews: [cancelButton, deleteButton]).then {
            $0.axis = .horizontal
            $0.spacing = 10
            $0.distribution = .fillEqually
        }
        cancelButton.snp.makeConstraints { $0.height.equalTo(48) }
        deleteButton.snp.makeConstraints { $0.height.equalTo(48) }

        let stack = UIStackView(arrangedSubviews: [title, buttonsRow]).then {
            $0.axis = .vertical
            $0.spacing = 8
            $0.alignment = .center
        }
        // 버튼 행 위쪽에 추가 여백 (top padding 8)
        stack.setCustomSpacing(16, after: title)

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
    @objc private func deleteTapped() { onDelete?() }
}
