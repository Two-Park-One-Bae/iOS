import UIKit
import SnapKit
import Then
import DSKit
import Domain

// ⑤ 인식 결과 리스트의 알약 1개 카드
final class PillResultRowView: UIView {

    var onTap: (() -> Void)?

    private let pill: IdentifiedPill

    init(pill: IdentifiedPill) {
        self.pill = pill
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = DSColor.Neutral._0
        layer.cornerRadius = 14
        layer.masksToBounds = false
        layer.shadowColor = DSColor.textPrimary.cgColor
        layer.shadowOpacity = 0.04
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 6

        let stack = UIStackView(arrangedSubviews: [makeHeader(), makeAttrs()]).then {
            $0.axis = .vertical
            $0.spacing = 10
        }
        addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(12)
            $0.leading.trailing.equalToSuperview().inset(14)
        }

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    @objc private func tapped() { onTap?() }

    // MARK: - Header

    private func makeHeader() -> UIView {
        let badge = UIView().then {
            $0.backgroundColor = DSColor.Primary._50
            $0.layer.cornerRadius = 13
            $0.layer.borderWidth = 1
            $0.layer.borderColor = DSColor.Primary._100.cgColor
        }
        let badgeLabel = UILabel().then {
            $0.text = "\(pill.index)"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 13)
            $0.textColor = DSColor.Primary._600
            $0.textAlignment = .center
        }
        badge.addSubview(badgeLabel)
        badge.snp.makeConstraints { $0.width.height.equalTo(26) }
        badgeLabel.snp.makeConstraints { $0.center.equalToSuperview() }

        let thumb = UIImageView().then {
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = 10
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFit
            $0.image = pill.thumbnail
        }
        thumb.snp.makeConstraints { $0.width.height.equalTo(40) }

        let title = UILabel().then {
            $0.text = "알약을 선택해주세요"
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 14)
            $0.textColor = DSColor.textSecondary
        }

        let pencil = UIImageView().then {
            $0.image = DSIcon.pencil.uiImage
            $0.tintColor = DSColor.Primary._500
            $0.contentMode = .scaleAspectFit
        }
        pencil.snp.makeConstraints { $0.width.height.equalTo(14) }

        let titleRow = UIStackView(arrangedSubviews: [title, pencil]).then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.alignment = .center
        }
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let header = UIStackView(arrangedSubviews: [badge, thumb, titleRow]).then {
            $0.axis = .horizontal
            $0.spacing = 10
            $0.alignment = .center
        }
        return header
    }

    // MARK: - Attributes

    private func makeAttrs() -> UIView {
        let attr = pill.attribute

        let colorGroup = makeAttrGroup(label: "색상", value: attr.colorsText)
        let shapeGroup = makeAttrGroup(label: "모양", value: attr.shape?.displayName ?? "미상")
        let formGroup  = makeAttrGroup(label: "제형", value: attr.formulation?.displayName ?? "미상")

        let chipsRow = UIStackView(arrangedSubviews: [colorGroup, shapeGroup, formGroup]).then {
            $0.axis = .horizontal
            $0.spacing = 10
            $0.alignment = .center
        }

        let frontRow = makeFaceRow(face: "앞", model: attr.front)
        let backRow  = makeFaceRow(face: "뒤", model: attr.back)

        let marks = UIStackView(arrangedSubviews: [frontRow, backRow]).then {
            $0.axis = .vertical
            $0.spacing = 5
        }

        let container = UIStackView(arrangedSubviews: [chipsRow, marks]).then {
            $0.axis = .vertical
            $0.spacing = 6
            $0.alignment = .leading
        }
        return container
    }

    private func makeAttrGroup(label: String, value: String) -> UIView {
        let lb = UILabel().then {
            $0.text = label
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 11)
            $0.textColor = DSColor.textTertiary
        }
        let chip = makeChip(text: value)
        let group = UIStackView(arrangedSubviews: [lb, chip]).then {
            $0.axis = .horizontal
            $0.spacing = 4
            $0.alignment = .center
        }
        return group
    }

    private func makeFaceRow(face: String, model: PillFaceModel?) -> UIView {
        let faceLabel = UILabel().then {
            $0.text = face
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 11)
            $0.textColor = DSColor.textTertiary
        }
        faceLabel.snp.makeConstraints { $0.width.equalTo(16) }

        let imprint = model?.imprint?.isEmpty == false ? model!.imprint! : "-"
        let line = model?.dividingLine?.displayName ?? "없음"
        let mark = (model?.hasMark == true) ? "있음" : "없음"

        let cols = UIStackView(arrangedSubviews: [
            makeMarkCol(label: "각인", value: imprint),
            makeMarkCol(label: "구분선", value: line),
            makeMarkCol(label: "마크", value: mark)
        ]).then {
            $0.axis = .horizontal
            $0.spacing = 4
            $0.alignment = .center
        }

        let row = UIStackView(arrangedSubviews: [faceLabel, cols]).then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.alignment = .center
        }
        return row
    }

    private func makeMarkCol(label: String, value: String) -> UIView {
        let lb = UILabel().then {
            $0.text = label
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 11)
            $0.textColor = DSColor.textTertiary
        }
        let chip = makeChip(text: value)
        let col = UIStackView(arrangedSubviews: [lb, chip]).then {
            $0.axis = .horizontal
            $0.spacing = 4
            $0.alignment = .center
        }
        return col
    }

    private func makeChip(text: String) -> UIView {
        let container = UIView().then {
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = 8
        }
        let label = UILabel().then {
            $0.text = text
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 12)
            $0.textColor = DSColor.textPrimary
        }
        container.addSubview(label)
        label.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(3)
            $0.leading.trailing.equalToSuperview().inset(7)
        }
        return container
    }
}
