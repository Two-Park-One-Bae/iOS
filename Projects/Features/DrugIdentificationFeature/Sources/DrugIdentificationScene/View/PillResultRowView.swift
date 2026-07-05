import UIKit
import SnapKit
import Then
import DSKit
import Domain

// ⑤ 인식 결과 리스트의 알약 1개 카드
final class PillResultRowView: UIView {

    var onTap: (() -> Void)?

    private let pill: IdentifiedPill

    private let titleLabel = UILabel().then {
        $0.text = "알약을 선택해주세요"
        $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 14)
        $0.textColor = DSColor.textSecondary
    }

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

        let pencil = UIImageView().then {
            $0.image = DSIcon.pencil.uiImage
            $0.tintColor = DSColor.Primary._500
            $0.contentMode = .scaleAspectFit
        }
        pencil.snp.makeConstraints { $0.width.height.equalTo(14) }

        let titleRow = UIStackView(arrangedSubviews: [titleLabel, pencil]).then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.alignment = .center
        }
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let header = UIStackView(arrangedSubviews: [badge, thumb, titleRow]).then {
            $0.axis = .horizontal
            $0.spacing = 10
            $0.alignment = .center
        }
        return header
    }

    // MARK: - Selection

    func showSelected(name: String) {
        titleLabel.text = name
        titleLabel.textColor = DSColor.textPrimary
        titleLabel.font = DSKitFontFamily.Pretendard.bold.font(size: 14)
        // 선택 시 카드 강조 (청록 배경 + 테두리)
        backgroundColor = DSColor.Secondary._50
        layer.borderColor = DSColor.Secondary._300.cgColor
        layer.borderWidth = 1.5
    }

    // MARK: - Attributes

    private func makeAttrs() -> UIView {
        let attr = pill.attribute

        let colorGroup = makeGroup(label: "색상", chip: makeColorChip(colors: attr.colors, transparent: attr.isTransparent))
        let shapeGroup = makeGroup(label: "모양", chip: makeShapeChip(attr.shape))
        let formGroup  = makeGroup(label: "제형", chip: makeFormulationChip(attr.formulation))

        let chipsRow = UIStackView(arrangedSubviews: [colorGroup, shapeGroup, formGroup, UIView()]).then {
            $0.axis = .horizontal
            $0.spacing = 10
            $0.alignment = .center
        }

        let summary = ImprintSummaryView()
        summary.update(front: attr.front, back: attr.back)

        let container = UIStackView(arrangedSubviews: [chipsRow, summary]).then {
            $0.axis = .vertical
            $0.spacing = 6
            $0.alignment = .leading
        }
        return container
    }

    // 라벨(색상/모양/제형) + 칩
    private func makeGroup(label: String, chip: UIView) -> UIView {
        let lb = UILabel().then {
            $0.text = label
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 11)
            $0.textColor = DSColor.textTertiary
        }
        return UIStackView(arrangedSubviews: [lb, chip]).then {
            $0.axis = .horizontal
            $0.spacing = 4
            $0.alignment = .center
        }
    }

    private func makeChipContainer() -> UIStackView {
        UIStackView().then {
            $0.axis = .horizontal
            $0.spacing = 4
            $0.alignment = .center
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = 8
            $0.isLayoutMarginsRelativeArrangement = true
            $0.layoutMargins = UIEdgeInsets(top: 3, left: 7, bottom: 3, right: 7)
        }
    }

    // 색상칩: 색 점들 (+ 투명 태그)
    private func makeColorChip(colors: [PillColorModel], transparent: Bool) -> UIView {
        let chip = makeChipContainer()
        let dots = UIStackView().then { $0.axis = .horizontal; $0.spacing = 3; $0.alignment = .center }
        let shown = colors.isEmpty ? [PillColorModel.unknown] : colors
        for color in shown {
            let dot = UIView().then {
                $0.backgroundColor = color.swatchColor ?? DSColor.Neutral._300
                $0.layer.cornerRadius = 6
                $0.layer.borderWidth = 1
                $0.layer.borderColor = DSColor.Neutral._200.cgColor
            }
            dot.snp.makeConstraints { $0.width.height.equalTo(12) }
            dots.addArrangedSubview(dot)
        }
        chip.addArrangedSubview(dots)

        if transparent {
            let tag = UIView().then {
                $0.layer.cornerRadius = 6
                $0.layer.borderWidth = 1
                $0.layer.borderColor = DSColor.Neutral._200.cgColor
            }
            let t = UILabel().then {
                $0.text = "투명"
                $0.font = DSKitFontFamily.Pretendard.medium.font(size: 11)
                $0.textColor = DSColor.textTertiary
            }
            tag.addSubview(t)
            t.snp.makeConstraints { $0.top.bottom.equalToSuperview(); $0.leading.trailing.equalToSuperview().inset(2) }
            chip.addArrangedSubview(tag)
        }
        return chip
    }

    // 모양칩: 글리프 + 텍스트
    private func makeShapeChip(_ shape: PillShapeModel?) -> UIView {
        let chip = makeChipContainer()
        if let shape {
            let glyph = ShapeGlyphView(shape: shape)
            glyph.snp.makeConstraints { $0.width.equalTo(18); $0.height.equalTo(11) }
            chip.addArrangedSubview(glyph)
        }
        chip.addArrangedSubview(makeChipLabel(shape?.displayName ?? "미상"))
        return chip
    }

    // 제형칩: 아이콘 + 축약 텍스트
    private func makeFormulationChip(_ formulation: PillFormulationModel?) -> UIView {
        let chip = makeChipContainer()
        if let formulation {
            let icon = FormulationIconView(formulation: formulation)
            icon.snp.makeConstraints { $0.width.height.equalTo(16) }
            chip.addArrangedSubview(icon)
        }
        chip.addArrangedSubview(makeChipLabel(formulation?.shortName ?? "미상"))
        return chip
    }

    private func makeChipLabel(_ text: String) -> UILabel {
        UILabel().then {
            $0.text = text
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 12)
            $0.textColor = DSColor.textSecondary
        }
    }
}
