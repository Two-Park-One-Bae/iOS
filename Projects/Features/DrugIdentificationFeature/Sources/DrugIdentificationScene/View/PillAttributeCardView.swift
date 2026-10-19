import UIKit
import SnapKit
import Then
import DSKit
import Domain

/// ⑧ 수정 화면 속성 카드 (V2.1.0 NM-588 `zSoDM`) — 늘 고칠 수 있다(접힘 · 펼침과 `수정` / `완료` 버튼은 없다).
///
/// 윗줄: 사진 · 이름 · 색상 / 모양 / 제형 칩. 그 아래 **앞면 | 뒷면** 두 칸(칸마다 각인, 그 아래 구분선 | 마크).
/// 값은 모두 드롭다운 칩(높이 30 · 글자 13). 각인 칩을 누르면 입력 줄이, 나머지 칩을 누르면 메뉴가 열린다.
/// 칩 테두리는 값이 **확실한지**로 정한다 — 회색 = 손대지 않음 · `모름` · 모델이 추정한 색·모양·제형,
/// 파랑 = 모델이 확신한 각인 · 마크 유무 + 사용자가 정한 값.
final class PillAttributeCardView: UIView {

    enum Action {
        case colors(anchor: UIView)
        case shape(anchor: UIView)
        case formulation(anchor: UIView)
        case imprintField(PillFace)
        case dividingLine(PillFace, anchor: UIView)
        case mark(PillFace, anchor: UIView)
    }

    var onAction: ((Action) -> Void)?

    private let title: String
    private let thumbnail: UIImage?
    private var conditions: PillConditions
    /// 각인 입력 중인 면 — 그 면의 각인 칩을 강조한다(primary-100 면 + 테두리 2).
    private var editingImprintFace: PillFace?

    private let stack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 6
    }

    init(title: String, thumbnail: UIImage?, conditions: PillConditions) {
        self.title = title
        self.thumbnail = thumbnail
        self.conditions = conditions
        super.init(frame: .zero)
        let surface = DSSurfaceView(spec: .glassCard)
        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(surface)
        addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(10)
            $0.leading.trailing.equalToSuperview().inset(10)
        }
        render()
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(conditions: PillConditions) {
        self.conditions = conditions
        render()
    }

    func setEditingImprint(_ face: PillFace?) {
        guard editingImprintFace != face else { return }
        editingImprintFace = face
        render()
    }

    // MARK: - Render

    private func render() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.addArrangedSubview(makeHeader())
        let faces = UIStackView(arrangedSubviews: [
            makeFace(.front, conditions.front), makeFace(.back, conditions.back),
        ]).then {
            $0.axis = .horizontal
            $0.spacing = 10
            $0.distribution = .fillEqually
            $0.alignment = .top
        }
        stack.addArrangedSubview(faces)
    }

    // MARK: 알약과 외형

    private func makeHeader() -> UIView {
        // 크롭은 알약 둘레에 딱 맞게 잘려 있어 칸을 꽉 채우면 둥근 모서리에 가장자리가 먹힌다 — 안쪽으로 들여 전체를 보인다.
        let crop = UIView().then {
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = DSRadius.md
            $0.clipsToBounds = true
        }
        let cropImage = UIImageView(image: thumbnail).then { $0.contentMode = .scaleAspectFit }
        crop.addSubview(cropImage)
        cropImage.snp.makeConstraints { $0.edges.equalToSuperview().inset(4) }
        crop.snp.makeConstraints { $0.width.height.equalTo(44) }

        let name = UILabel().then {
            $0.text = title
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 15)
            $0.textColor = DSColor.textPrimary
        }
        let appearance = UIStackView(arrangedSubviews: [
            inlineGroup("색상", AttributeChip(content: colorContent(), tone: conditions.colors.tone)) { [weak self] in
                self?.onAction?(.colors(anchor: $0))
            },
            inlineGroup("모양", AttributeChip(content: shapeContent(), tone: conditions.shape.tone)) { [weak self] in
                self?.onAction?(.shape(anchor: $0))
            },
            inlineGroup("제형", AttributeChip(content: formulationContent(), tone: conditions.formulation.tone)) { [weak self] in
                self?.onAction?(.formulation(anchor: $0))
            },
        ]).then {
            $0.axis = .horizontal
            $0.spacing = 10
            $0.alignment = .center
        }
        let texts = UIStackView(arrangedSubviews: [name, appearance]).then {
            $0.axis = .vertical
            $0.spacing = 4
            $0.alignment = .leading
        }
        return UIStackView(arrangedSubviews: [crop, texts, UIView()]).then {
            $0.axis = .horizontal
            $0.spacing = 12
            $0.alignment = .center
        }
    }

    /// `라벨 [칩]` 가로 묶음 — 색상 · 모양 · 제형.
    private func inlineGroup(_ label: String, _ chip: AttributeChip, onTap: @escaping (UIView) -> Void) -> UIView {
        configure(chip, label: label, onTap: onTap)
        return UIStackView(arrangedSubviews: [smallLabel(label), chip]).then {
            $0.axis = .horizontal
            $0.spacing = 4
            $0.alignment = .center
        }
    }

    private func configure(_ chip: AttributeChip, label: String, onTap: @escaping (UIView) -> Void) {
        chip.addAction(UIAction { _ in onTap(chip) }, for: .touchUpInside)
        chip.isAccessibilityElement = true
        chip.accessibilityTraits = .button
        chip.accessibilityLabel = label
        chip.accessibilityIdentifier = "attributeChip.\(label)"
    }

    /// 사용자가 고른 색은 이름별 팔레트 색, 아니면 모델이 잰 색(colorHexes). 둘 다 없으면 `선택`.
    private func colorContent() -> UIView {
        let colors: [UIColor]
        if let user = conditions.colors.userValue {
            colors = user.map { $0.swatchColor ?? DSColor.Neutral._0 }
        } else {
            colors = conditions.model.colorHexes.compactMap(UIColor.init(pillHex:))
        }
        guard !colors.isEmpty else { return chipText("선택", state: .untouched) }
        return ColorPieView(colors: colors).then { $0.snp.makeConstraints { $0.width.height.equalTo(14) } }
    }

    private func shapeContent() -> UIView {
        guard let shape = conditions.shape.userValue ?? conditions.model.shape else {
            return chipText("선택", state: .untouched)
        }
        let glyph = ShapeGlyphView(shape: shape)
        glyph.setTint(conditions.shape.tone == .confirmed ? DSColor.Primary._500 : DSColor.textSecondary)
        glyph.snp.makeConstraints { $0.width.equalTo(17); $0.height.equalTo(11) }
        return glyph
    }

    private func formulationContent() -> UIView {
        guard let formulation = conditions.formulation.userValue ?? conditions.model.formulation,
              formulation != .other, formulation != .unknown else {
            // '기타' 제형은 그림이 없어 글자로 둔다.
            if conditions.formulation.userValue == .other {
                return chipText("기타", state: .confirmed)
            }
            return chipText("선택", state: .untouched)
        }
        let icon = FormulationIconView(formulation: formulation)
        icon.setTint(conditions.formulation.tone == .confirmed ? DSColor.Primary._500 : DSColor.textSecondary)
        icon.snp.makeConstraints {
            $0.width.equalTo(formulation == .tablet ? 15 : 20)
            $0.height.equalTo(formulation == .tablet ? 15 : 11)
        }
        return icon
    }

    // MARK: 면 카드

    /// 면 이름 · 각인 줄(칩이 폭 가득) · 구분선 | 마크. Neutral50 · r12 · padding (5, 8, 6, 8).
    private func makeFace(_ face: PillFace, _ c: FaceConditions) -> UIView {
        let box = UIView().then {
            $0.backgroundColor = DSColor.Neutral._50
            $0.layer.cornerRadius = DSRadius.md
        }
        let faceLabel = UILabel().then {
            $0.text = face == .front ? "앞면" : "뒷면"
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 11)
            $0.textColor = DSColor.textSecondary
        }

        // 각인 — 누르면 메뉴 없이 바로 입력 줄. 입력하는 동안은 그 면의 칩을 강조한다.
        let imprint = imprintDisplay(c.imprint)
        let imprintChip = AttributeChip(
            content: chipText(imprint.text, state: imprint.state, fill: true),
            tone: c.imprint.tone,
            highlighted: editingImprintFace == face
        )
        configure(imprintChip, label: "\(face == .front ? "앞면" : "뒷면") 각인") { [weak self] _ in
            self?.onAction?(.imprintField(face))
        }
        let imprintRow = UIStackView(arrangedSubviews: [smallLabel("각인"), imprintChip]).then {
            $0.axis = .horizontal
            $0.spacing = 6
            $0.alignment = .center
        }

        let dividing = dividingDisplay(c.dividingLine)
        let dividingChip = AttributeChip(content: dividing, tone: c.dividingLine.tone)
        configure(dividingChip, label: "\(face == .front ? "앞면" : "뒷면") 구분선") { [weak self] in
            self?.onAction?(.dividingLine(face, anchor: $0))
        }
        let mark = markDisplay(c.mark)
        let markChip = AttributeChip(content: chipText(mark.text, state: mark.state), tone: c.mark.tone)
        configure(markChip, label: "\(face == .front ? "앞면" : "뒷면") 마크") { [weak self] in
            self?.onAction?(.mark(face, anchor: $0))
        }
        let divider = UIView().then {
            $0.backgroundColor = DSColor.Neutral._200
            $0.snp.makeConstraints { $0.width.equalTo(1); $0.height.equalTo(30) }
        }
        let lower = UIStackView(arrangedSubviews: [
            stackedGroup("구분선", dividingChip), divider, stackedGroup("마크", markChip), UIView(),
        ]).then {
            $0.axis = .horizontal
            $0.spacing = 7
            $0.alignment = .bottom
        }

        let stack = UIStackView(arrangedSubviews: [faceLabel, imprintRow, lower]).then {
            $0.axis = .vertical
            $0.spacing = 4
        }
        box.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 5, left: 8, bottom: 6, right: 8)) }
        return box
    }

    /// 라벨 위 · 칩 아래 세로 묶음 — 구분선 · 마크.
    private func stackedGroup(_ label: String, _ chip: AttributeChip) -> UIView {
        UIStackView(arrangedSubviews: [smallLabel(label), chip]).then {
            $0.axis = .vertical
            $0.spacing = 2
            $0.alignment = .leading
        }
    }

    // MARK: 글자

    /// 칩 글자의 상태 — 손대지 않음(회색 안내 글자) · 모름 · 확실한 값(파랑).
    enum ChipTextState {
        case untouched
        case estimate
        case confirmed
    }

    private func imprintDisplay(_ c: ImprintCondition) -> (text: String, state: ChipTextState) {
        switch c {
        case .all:                 return ("입력", .untouched)
        case .unknown:             return ("모름", .estimate)
        case .none:                return ("없음", .confirmed)
        case .value(let text, _):  return (text, .confirmed)
        }
    }

    private func dividingDisplay(_ c: DividingLineCondition) -> UIView {
        switch c {
        case .all:                return chipText("선택", state: .untouched)
        case .unknown:            return chipText("모름", state: .estimate)
        case .none:               return chipText("없음", state: .confirmed)
        case .value(.unknown):    return chipText("선택", state: .untouched)
        case .value(let line):
            let glyph = DividingLineGlyphView(line: line, tint: DSColor.Primary._500)
            glyph.snp.makeConstraints { $0.width.height.equalTo(14) }
            return UIStackView(arrangedSubviews: [glyph, chipText(line == .plus ? "(+)형" : "(−)형", state: .confirmed)]).then {
                $0.axis = .horizontal
                $0.spacing = 4
                $0.alignment = .center
            }
        }
    }

    private func markDisplay(_ c: MarkCondition) -> (text: String, state: ChipTextState) {
        switch c {
        case .all:      return ("선택", .untouched)
        case .unknown:  return ("모름", .estimate)
        case .none:     return ("없음", .confirmed)
        case .present:  return ("있음", .confirmed)
        }
    }

    private func chipText(_ text: String, state: ChipTextState, fill: Bool = false) -> UILabel {
        UILabel().then {
            $0.text = text
            $0.lineBreakMode = .byTruncatingTail
            switch state {
            case .untouched:
                $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
                $0.textColor = DSColor.textTertiary
            case .estimate:
                $0.font = DSKitFontFamily.Pretendard.medium.font(size: 13)
                $0.textColor = DSColor.textPrimary
            case .confirmed:
                $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 13)
                $0.textColor = DSColor.Primary._600
            }
            if fill { $0.setContentHuggingPriority(.defaultLow, for: .horizontal) }
            $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
    }

    private func smallLabel(_ text: String) -> UILabel {
        UILabel().then {
            $0.text = text
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 11)
            $0.textColor = DSColor.textTertiary
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
    }
}

// MARK: - 드롭다운 칩

/// 속성 카드의 드롭다운 칩 — 흰 볼록(raisedNeutral), 캡슐, 높이 30, padding (0, 10, 0, 12), 내용 + ▾ 16.
/// 확실한 값은 파란 테두리 1.5(▾ Primary500), 각인 입력 중이면 Primary100 면 + 테두리 2.
/// 누르는 영역은 위아래로 늘려 44 를 맞춘다.
final class AttributeChip: UIControl {

    private let surface: DSSurfaceView

    init(content: UIView, tone: ConditionTone, highlighted: Bool = false) {
        if highlighted {
            surface = DSSurfaceView(spec: .flat(DSColor.Primary._100, stroke: DSColor.Primary._500, strokeWidth: 2), cornerRadius: nil)
        } else if tone == .confirmed {
            surface = DSSurfaceView(spec: .raisedNeutral(stroke: DSColor.Primary._500, strokeWidth: 1.5), cornerRadius: nil)
        } else {
            surface = DSSurfaceView(spec: .raisedNeutral(), cornerRadius: nil)
        }
        super.init(frame: .zero)
        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(surface)

        let chevron = UIImageView(image: DSIcon.chevronDown.uiImage).then {
            $0.tintColor = tone == .confirmed || highlighted ? DSColor.Primary._500 : DSColor.textTertiary
            $0.contentMode = .scaleAspectFit
            $0.snp.makeConstraints { $0.width.height.equalTo(16) }
        }
        let row = UIStackView(arrangedSubviews: [content, chevron]).then {
            $0.axis = .horizontal
            $0.spacing = 2
            $0.alignment = .center
            $0.isUserInteractionEnabled = false
        }
        addSubview(row)
        snp.makeConstraints { $0.height.equalTo(30) }
        row.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview().inset(12)
            $0.trailing.equalToSuperview().inset(10)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { surface.alpha = isHighlighted ? 0.85 : 1 }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: 0, dy: -7).contains(point)
    }
}

// MARK: - 조각 원 (여러 색)

/// 색이 여럿이면 원 하나를 조각으로 — 12시 방향 시작 · 시계 방향 · 색 순서 그대로 · 테두리 원 (NM-490 MC-2).
final class ColorPieView: UIView {
    private let colors: [UIColor]

    init(colors: [UIColor]) {
        self.colors = colors
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard !colors.isEmpty, let ctx = UIGraphicsGetCurrentContext() else { return }
        let box = rect.insetBy(dx: 0.5, dy: 0.5)
        let center = CGPoint(x: box.midX, y: box.midY)
        let radius = box.width / 2
        let step = 2 * CGFloat.pi / CGFloat(colors.count)
        var start = -CGFloat.pi / 2
        for color in colors {
            ctx.move(to: center)
            ctx.addArc(center: center, radius: radius, startAngle: start, endAngle: start + step, clockwise: false)
            ctx.closePath()
            ctx.setFillColor(color.cgColor)
            ctx.fillPath()
            start += step
        }
        ctx.setStrokeColor(DSColor.Neutral._300.cgColor)
        ctx.setLineWidth(1)
        ctx.strokeEllipse(in: box)
    }
}

// MARK: - 구분선 그림

/// 구분선 알약 그림 — 원 위에 (+) 또는 (−). `없음` 은 선 없는 원.
final class DividingLineGlyphView: UIView {
    private let line: DividingLineModel?
    private let tint: UIColor

    init(line: DividingLineModel?, tint: UIColor) {
        self.line = line
        self.tint = tint
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let d = min(rect.width, rect.height) - 1
        let disc = CGRect(x: rect.midX - d / 2, y: rect.midY - d / 2, width: d, height: d)
        ctx.setFillColor(tint.cgColor)
        ctx.fillEllipse(in: disc)
        ctx.setStrokeColor(DSColor.surface.cgColor)
        ctx.setLineWidth(max(1.5, d * 0.1))
        ctx.setLineCap(.round)
        let arm = d * 0.32
        if line == .plus || line == .minus {
            ctx.move(to: CGPoint(x: disc.midX - arm, y: disc.midY))
            ctx.addLine(to: CGPoint(x: disc.midX + arm, y: disc.midY))
        }
        if line == .plus {
            ctx.move(to: CGPoint(x: disc.midX, y: disc.midY - arm))
            ctx.addLine(to: CGPoint(x: disc.midX, y: disc.midY + arm))
        }
        ctx.strokePath()
    }
}

extension UIColor {
    /// spec colorHexes `#RRGGBB`. 형식이 어긋나면 nil(매핑 단계에서 이미 걸렀다).
    convenience init?(pillHex: String) {
        guard pillHex.count == 7, pillHex.first == "#", let v = UInt32(pillHex.dropFirst(), radix: 16) else { return nil }
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}
