import UIKit
import SnapKit
import Then
import DSKit

// 알약 액션 팝업 메뉴 카드 (⋮ 메뉴: 수정 / 삭제)
final class PillActionMenuView: UIView {

    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        // Card (자기 자신을 카드로 사용 — shadow가 보이도록 clip 하지 않음)
        backgroundColor = DSColor.Neutral._0
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = DSColor.Neutral._200.cgColor
        layer.masksToBounds = false

        // Outer shadow
        layer.shadowColor = DSColor.textPrimary.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 16

        snp.makeConstraints { $0.width.equalTo(150) }

        // Rows
        let editRow = makeRow(
            icon: DSIcon.pencil.uiImage,
            iconTint: DSColor.textSecondary,
            title: "수정",
            titleColor: DSColor.textPrimary,
            action: #selector(editTapped)
        )
        let divider = UIView().then {
            $0.backgroundColor = DSColor.Neutral._100
        }
        let deleteRow = makeRow(
            icon: DSIcon.trash.uiImage,
            iconTint: DSColor.Error._500,
            title: "삭제",
            titleColor: DSColor.Error._500,
            action: #selector(deleteTapped)
        )

        let stack = UIStackView(arrangedSubviews: [editRow, divider, deleteRow]).then {
            $0.axis = .vertical
            $0.alignment = .fill
        }
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }
        divider.snp.makeConstraints { $0.height.equalTo(1) }
    }

    private func makeRow(
        icon: UIImage,
        iconTint: UIColor,
        title: String,
        titleColor: UIColor,
        action: Selector
    ) -> UIControl {
        let row = UIControl()

        let imageView = UIImageView().then {
            $0.image = icon
            $0.tintColor = iconTint
            $0.contentMode = .scaleAspectFit
            $0.isUserInteractionEnabled = false
        }
        let label = UILabel().then {
            $0.text = title
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 14)
            $0.textColor = titleColor
            $0.isUserInteractionEnabled = false
        }

        let content = UIStackView(arrangedSubviews: [imageView, label]).then {
            $0.axis = .horizontal
            $0.spacing = 10
            $0.alignment = .center
            $0.isUserInteractionEnabled = false
        }
        row.addSubview(content)
        content.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(12)
            $0.leading.trailing.equalToSuperview().inset(14)
        }
        imageView.snp.makeConstraints { $0.width.height.equalTo(16) }

        row.addTarget(self, action: action, for: .touchUpInside)
        return row
    }

    @objc private func editTapped() { onEdit?() }
    @objc private func deleteTapped() { onDelete?() }
}
