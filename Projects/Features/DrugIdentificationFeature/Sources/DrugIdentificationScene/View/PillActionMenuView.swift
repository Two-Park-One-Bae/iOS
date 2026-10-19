import UIKit
import SnapKit
import Then
import DSKit

// 알약 액션 팝업 메뉴 카드 (⋮ 메뉴: 수정 / 삭제). 기록 상세는 고쳐 쓰지 않아 삭제만 둔다.
final class PillActionMenuView: UIView {

    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    private let showsEdit: Bool

    init(showsEdit: Bool = true) {
        self.showsEdit = showsEdit
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        // V2.1.0 Menu(`kZaQ3`) — 흰 평면, r12, 테두리 Border, 목록 그림자, 폭 160
        let surface = DSSurfaceView(
            spec: DSSurfaceSpec(
                fills: [.solid(DSColor.surface)],
                stroke: .solid(DSColor.border),
                shadows: [
                    DSShadow(color: DSColor.Neutral._900.withAlphaComponent(0.09), y: 8, blur: 22),
                    DSShadow(color: DSColor.Neutral._900.withAlphaComponent(0.08), y: 1, blur: 2)
                ]
            ),
            cornerRadius: DSRadius.md
        )
        addSubview(surface)
        surface.snp.makeConstraints { $0.edges.equalToSuperview() }

        snp.makeConstraints { $0.width.equalTo(160) }

        // Rows
        let editRow = makeRow(
            icon: DSIcon.pencil.uiImage,
            iconTint: DSColor.textPrimary,
            title: "수정",
            titleColor: DSColor.textPrimary,
            action: #selector(editTapped)
        )
        let divider = UIView().then {
            $0.backgroundColor = DSColor.Neutral._100
        }
        let deleteRow = makeRow(
            icon: DSIcon.trash.uiImage,
            iconTint: DSColor.Error._600,
            title: "삭제",
            titleColor: DSColor.Error._600,
            action: #selector(deleteTapped)
        )

        editRow.isHidden = !showsEdit
        divider.isHidden = !showsEdit

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
            $0.centerY.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(14)
        }
        row.snp.makeConstraints { $0.height.equalTo(44) }
        imageView.snp.makeConstraints { $0.width.height.equalTo(18) }

        row.addTarget(self, action: action, for: .touchUpInside)
        return row
    }

    @objc private func editTapped() { onEdit?() }
    @objc private func deleteTapped() { onDelete?() }
}
