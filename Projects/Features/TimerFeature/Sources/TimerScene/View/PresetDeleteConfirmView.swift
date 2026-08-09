import UIKit
import SnapKit
import Then
import DSKit

// C3 프리셋 삭제 확인 카드 (O3Bz3) — 딤/센터링은 호출자가 처리
final class PresetDeleteConfirmView: UIView {

    var onCancel: (() -> Void)?
    var onDelete: (() -> Void)?

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = DSColor.Neutral._0
        layer.cornerRadius = 16
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 24
        snp.makeConstraints { $0.width.equalTo(300) }

        let title = UILabel().then {
            $0.text = "이 프리셋을 삭제할까요?"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 16)
            $0.textColor = DSColor.textPrimary
            $0.textAlignment = .center
        }

        let cancel = makeButton(title: "취소", bg: DSColor.Neutral._100, text: DSColor.textPrimary)
        let delete = makeButton(title: "삭제", bg: DSColor.Error._500, text: DSColor.Neutral._0)
        cancel.addAction(UIAction { [weak self] _ in self?.onCancel?() }, for: .touchUpInside)
        delete.addAction(UIAction { [weak self] _ in self?.onDelete?() }, for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [cancel, delete]).then {
            $0.axis = .horizontal; $0.spacing = 10; $0.distribution = .fillEqually
        }

        let stack = UIStackView(arrangedSubviews: [title, buttons]).then {
            $0.axis = .vertical; $0.spacing = 16
        }
        addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(22)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalToSuperview().offset(-16)
        }
    }

    private func makeButton(title: String, bg: UIColor, text: UIColor) -> UIControl {
        let button = UIControl().then {
            $0.backgroundColor = bg
            $0.layer.cornerRadius = 12
        }
        let label = UILabel().then {
            $0.text = title
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 15)
            $0.textColor = text
            $0.textAlignment = .center
            $0.isUserInteractionEnabled = false
        }
        button.addSubview(label)
        label.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 13, left: 8, bottom: 13, right: 8)) }
        return button
    }
}
