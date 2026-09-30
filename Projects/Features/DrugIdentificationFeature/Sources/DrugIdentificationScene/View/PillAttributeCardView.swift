import UIKit
import SnapKit
import Then
import DSKit
import Domain

/// ⑧ 수정 화면 속성 카드 (DESIGN.pen NM-490 ⑧-a) — 접힘(읽기) / 펼침(편집) 두 모양.
///
/// 조건(`PillConditions`) 하나로 전부 다시 그린다. 칸 색은 값이 **확실한지**로 정한다 —
/// 회색 = `전체` · 모델이 추정한 색·모양·제형, 호박색 = 모델이 확신한 각인·마크 + 사용자가 정한 값.
final class PillAttributeCardView: UIView {

    enum Action {
        case toggleExpanded
        case colors(anchor: UIView)
        case shape(anchor: UIView)
        case formulation(anchor: UIView)
        case imprintMenu(PillFace, anchor: UIView)
        case imprintField(PillFace)
        case revertImprint(PillFace)
        case dividingLine(PillFace, anchor: UIView)
        case mark(PillFace, anchor: UIView)
    }

    var onAction: ((Action) -> Void)?

    private let title: String
    private let thumbnail: UIImage?
    private(set) var isExpanded: Bool
    private var conditions: PillConditions

    private let stack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 12
    }

    init(title: String, thumbnail: UIImage?, conditions: PillConditions, expanded: Bool) {
        self.title = title
        self.thumbnail = thumbnail
        self.conditions = conditions
        self.isExpanded = expanded
        super.init(frame: .zero)
        backgroundColor = DSColor.surface
        layer.cornerRadius = 16
        layer.shadowColor = DSColor.textPrimary.cgColor
        layer.shadowOpacity = 0.04
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 6
        addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().inset(12)
            $0.leading.trailing.bottom.equalToSuperview().inset(14)
        }
        render()
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(conditions: PillConditions) {
        self.conditions = conditions
        render()
    }

    func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
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
        let crop = UIImageView(image: thumbnail).then {
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = 10
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFit
        }
        crop.snp.makeConstraints { $0.width.height.equalTo(44) }

        let name = UILabel().then {
            $0.text = title
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 15)
            $0.textColor = DSColor.textPrimary
        }
        let appearance = UIStackView(arrangedSubviews: [
            chipGroup("색상", chip(tone: conditions.colors.tone, content: colorContent())) { [weak self] in
                self?.onAction?(.colors(anchor: $0))
            },
            chipGroup("모양", chip(tone: conditions.shape.tone, content: shapeContent())) { [weak self] in
                self?.onAction?(.shape(anchor: $0))
            },
            chipGroup("제형", chip(tone: conditions.formulation.tone, content: formulationContent())) { [weak self] in
                self?.onAction?(.formulation(anchor: $0))
            },
        ]).then {
            $0.axis = .horizontal
            $0.spacing = isExpanded ? 6 : 10
            $0.alignment = .center
        }
        let texts = UIStackView(arrangedSubviews: [name, appearance]).then {
            $0.axis = .vertical
            $0.spacing = 5
            $0.alignment = .leading
        }

        let toggle = UIButton(type: .system).then {
            $0.backgroundColor = isExpanded ? DSColor.Primary._500 : DSColor.Neutral._100
            $0.layer.cornerRadius = 17
            $0.setImage((isExpanded ? DSIcon.check : DSIcon.slidersHorizontal).uiImage, for: .normal)
            $0.tintColor = isExpanded ? DSColor.Neutral._0 : DSColor.textSecondary
            $0.accessibilityLabel = isExpanded ? "완료" : "수정"
            $0.addAction(UIAction { [weak self] _ in self?.onAction?(.toggleExpanded) }, for: .touchUpInside)
        }
        toggle.snp.makeConstraints { $0.width.height.equalTo(34) }

        return UIStackView(arrangedSubviews: [crop, texts, UIView(), toggle]).then {
            $0.axis = .horizontal
            $0.spacing = 12
            $0.alignment = .center
        }
    }

    private func chipGroup(_ label: String, _ chip: UIControl, onTap: @escaping (UIView) -> Void) -> UIView {
        // 접힘은 읽기 전용이라 칩을 눌러도 메뉴가 열리지 않는다 — 수정 버튼으로 펼친다.
        chip.isUserInteractionEnabled = isExpanded
        chip.addAction(UIAction { _ in onTap(chip) }, for: .touchUpInside)
        chip.isAccessibilityElement = true
        chip.accessibilityTraits = .button
        chip.accessibilityLabel = label
        chip.accessibilityIdentifier = "attributeChip.\(label)"
        return UIStackView(arrangedSubviews: [smallLabel(label), chip]).then {
            $0.axis = .horizontal
            $0.spacing = isExpanded ? 3 : 4
            $0.alignment = .center
        }
    }

    private func chip(tone: ConditionTone, content: UIView) -> UIControl {
        let chip = UIControl().then {
            $0.backgroundColor = tone == .confirmed ? DSColor.Warning._50 : DSColor.Neutral._100
            $0.layer.cornerRadius = 13
            // 펼침에서는 누를 수 있다는 걸 테두리로 드러낸다.
            let border: UIColor? = tone == .confirmed ? DSColor.Warning._300 : (isExpanded ? DSColor.Neutral._300 : nil)
            $0.layer.borderColor = border?.cgColor
            $0.layer.borderWidth = border == nil ? 0 : 1
        }
        var items: [UIView] = [content]
        if isExpanded {
            items.append(UIImageView(image: DSIcon.chevronDown.uiImage).then {
                $0.tintColor = DSColor.textTertiary
                $0.contentMode = .scaleAspectFit
                $0.snp.makeConstraints { $0.width.height.equalTo(8) }
            })
        }
        let row = UIStackView(arrangedSubviews: items).then {
            $0.axis = .horizontal
            $0.spacing = isExpanded ? 3 : 4
            $0.alignment = .center
            $0.isUserInteractionEnabled = false
        }
        chip.addSubview(row)
        chip.snp.makeConstraints { $0.height.equalTo(26) }
        row.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview().inset(isExpanded ? 7 : 8)
            $0.trailing.equalToSuperview().inset(isExpanded ? 5 : 8)
        }
        return chip
    }

    /// 사용자가 고른 색은 이름별 팔레트 색, 아니면 모델이 잰 색(colorHexes). 둘 다 없으면 `전체`.
    private func colorContent() -> UIView {
        let colors: [UIColor]
        if let user = conditions.colors.userValue {
            colors = user.map { $0.swatchColor ?? DSColor.Neutral._0 }
        } else {
            colors = conditions.model.colorHexes.compactMap(UIColor.init(pillHex:))
        }
        guard !colors.isEmpty else { return allText(tone: conditions.colors.tone) }
        return ColorPieView(colors: colors).then { $0.snp.makeConstraints { $0.width.height.equalTo(13) } }
    }

    private func shapeContent() -> UIView {
        guard let shape = conditions.shape.userValue ?? conditions.model.shape else {
            return allText(tone: conditions.shape.tone)
        }
        let glyph = ShapeGlyphView(shape: shape)
        glyph.setTint(conditions.shape.tone == .confirmed ? DSColor.Warning._700 : DSColor.textSecondary)
        glyph.snp.makeConstraints { $0.width.equalTo(17); $0.height.equalTo(11) }
        return glyph
    }

    private func formulationContent() -> UIView {
        guard let formulation = conditions.formulation.userValue ?? conditions.model.formulation,
              formulation != .other, formulation != .unknown else {
            // '기타' 제형은 그림이 없어 글자로 둔다.
            if conditions.formulation.userValue == .other {
                return valueText("기타", tone: .confirmed, size: 12)
            }
            return allText(tone: conditions.formulation.tone)
        }
        let icon = FormulationIconView(formulation: formulation)
        icon.setTint(conditions.formulation.tone == .confirmed ? DSColor.Warning._700 : DSColor.textSecondary)
        icon.snp.makeConstraints {
            $0.width.equalTo(formulation == .tablet ? 15 : 20)
            $0.height.equalTo(formulation == .tablet ? 15 : 11)
        }
        return icon
    }

    // MARK: 면 카드

    private func makeFace(_ face: PillFace, _ c: FaceConditions) -> UIView {
        let box = UIView().then {
            $0.backgroundColor = DSColor.Neutral._50
            $0.layer.cornerRadius = isExpanded ? 12 : 10
            $0.layer.borderWidth = 1
            $0.layer.borderColor = DSColor.Neutral._200.cgColor
        }
        let title = UILabel().then {
            $0.text = face == .front ? "앞면" : "뒷면"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: isExpanded ? 12 : 11)
            $0.textColor = DSColor.textSecondary
        }
        let content = UIStackView(arrangedSubviews: [title]).then {
            $0.axis = .vertical
            $0.spacing = isExpanded ? 8 : 6
            $0.alignment = .fill
        }
        if isExpanded {
            buildExpandedFace(face, c, into: content)
        } else {
            buildCollapsedFace(c, into: content)
        }
        box.addSubview(content)
        content.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(isExpanded ? 10 : 8)
            $0.leading.trailing.equalToSuperview().inset(10)
        }
        return box
    }

    private func buildCollapsedFace(_ c: FaceConditions, into stack: UIStackView) {
        let imprintValue = pill(text: imprintText(c.imprint), tone: c.imprint.tone, large: true)
        let imprintRow = UIStackView(arrangedSubviews: [smallLabel("각인"), imprintValue, UIView()]).then {
            $0.axis = .horizontal
            $0.spacing = 6
            $0.alignment = .center
        }
        imprintValue.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let line = labeled("구분선", dividingPill(c.dividingLine))
        let divider = UIView().then {
            $0.backgroundColor = DSColor.Neutral._200
            $0.snp.makeConstraints { $0.width.equalTo(1); $0.height.equalTo(22) }
        }
        let mark = labeled("마크", pill(text: markText(c.mark), tone: c.mark.tone, large: false))
        let lineMark = UIStackView(arrangedSubviews: [line, divider, mark, UIView()]).then {
            $0.axis = .horizontal
            $0.spacing = 4
            $0.alignment = .center
        }
        stack.addArrangedSubview(imprintRow)
        stack.addArrangedSubview(lineMark)
    }

    private func buildExpandedFace(_ face: PillFace, _ c: FaceConditions, into stack: UIStackView) {
        let menu = dropdown(text: imprintMenuText(c.imprint), tone: c.imprint.tone) { [weak self] in
            self?.onAction?(.imprintMenu(face, anchor: $0))
        }
        menu.accessibilityLabel = "\(face == .front ? "앞면" : "뒷면") 각인"
        menu.snp.makeConstraints { $0.width.equalTo(74) }
        stack.addArrangedSubview(UIStackView(arrangedSubviews: [smallLabel("각인"), UIView(), menu]).then {
            $0.axis = .horizontal
            $0.spacing = 6
            $0.alignment = .center
        })

        // 값이 있을 때만 입력칸 — 누르면 키보드 위 입력 줄이 뜬다. 되돌리기는 사용자가 바꾼 값일 때만.
        if case let .value(text, source) = c.imprint {
            stack.addArrangedSubview(imprintField(face, text: text, canRevert: source == .user))
        }

        let line = dropdown(text: dividingMenuText(c.dividingLine), tone: c.dividingLine.tone) { [weak self] in
            self?.onAction?(.dividingLine(face, anchor: $0))
        }
        line.accessibilityLabel = "\(face == .front ? "앞면" : "뒷면") 구분선"
        let mark = dropdown(text: markText(c.mark), tone: c.mark.tone) { [weak self] in
            self?.onAction?(.mark(face, anchor: $0))
        }
        mark.accessibilityLabel = "\(face == .front ? "앞면" : "뒷면") 마크"
        let divider = UIView().then {
            $0.backgroundColor = DSColor.Neutral._200
            $0.snp.makeConstraints { $0.width.equalTo(1); $0.height.equalTo(48) }
        }
        let row = UIStackView(arrangedSubviews: [labeledFill("구분선", line), divider, labeledFill("마크", mark)]).then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.alignment = .center
        }
        // 위쪽 가는 선으로 각인과 구분한다.
        let wrap = UIView()
        let topLine = UIView().then { $0.backgroundColor = DSColor.Neutral._200 }
        wrap.addSubview(topLine)
        wrap.addSubview(row)
        topLine.snp.makeConstraints { $0.top.leading.trailing.equalToSuperview(); $0.height.equalTo(1) }
        row.snp.makeConstraints { $0.top.equalToSuperview().inset(8); $0.leading.trailing.bottom.equalToSuperview() }
        (row.arrangedSubviews[0]).snp.makeConstraints { $0.width.equalTo(row.arrangedSubviews[2]) }
        stack.addArrangedSubview(wrap)
    }

    private func imprintField(_ face: PillFace, text: String, canRevert: Bool) -> UIView {
        let field = UIControl().then {
            $0.backgroundColor = DSColor.Warning._50
            $0.layer.cornerRadius = 8
            $0.layer.borderWidth = 1
            $0.layer.borderColor = DSColor.Warning._300.cgColor
            $0.isAccessibilityElement = true
            $0.accessibilityTraits = .button
            $0.accessibilityLabel = "각인 \(text)"
            $0.addAction(UIAction { [weak self] _ in self?.onAction?(.imprintField(face)) }, for: .touchUpInside)
        }
        field.snp.makeConstraints { $0.height.equalTo(34) }
        let label = UILabel().then {
            $0.text = text
            $0.font = DSKitFontFamily.Pretendard.extraBold.font(size: 15)
            $0.textColor = DSColor.textPrimary
            $0.lineBreakMode = .byTruncatingTail
        }
        field.addSubview(label)
        label.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview().inset(8)
            $0.trailing.lessThanOrEqualToSuperview().inset(canRevert ? 32 : 8)
        }
        if canRevert {
            let revert = UIButton(type: .system).then {
                $0.setImage(UIImage(systemName: "arrow.uturn.backward",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)), for: .normal)
                $0.tintColor = DSColor.Warning._700
                $0.accessibilityLabel = "되돌리기"
                $0.addAction(UIAction { [weak self] _ in self?.onAction?(.revertImprint(face)) }, for: .touchUpInside)
            }
            field.addSubview(revert)
            // 칸 전체가 접근성 요소라 안쪽 버튼이 가려진다 — 되돌리기는 칸의 동작으로 노출한다.
            field.accessibilityCustomActions = [
                UIAccessibilityCustomAction(name: "되돌리기") { [weak self] _ in
                    self?.onAction?(.revertImprint(face))
                    return true
                },
            ]
            revert.snp.makeConstraints {
                $0.centerY.equalToSuperview()
                $0.trailing.equalToSuperview().inset(2)
                $0.width.height.equalTo(28)
            }
        }
        return field
    }

    // MARK: 부품

    private func smallLabel(_ text: String) -> UILabel {
        UILabel().then {
            $0.text = text
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 11)
            $0.textColor = DSColor.textTertiary
            $0.setContentHuggingPriority(.required, for: .horizontal)
        }
    }

    private func allText(tone: ConditionTone) -> UIView {
        valueText("전체", tone: tone, size: 12)
    }

    private func valueText(_ text: String, tone: ConditionTone, size: CGFloat) -> UILabel {
        UILabel().then {
            $0.text = text
            $0.font = tone == .confirmed
                ? DSKitFontFamily.Pretendard.bold.font(size: size)
                : DSKitFontFamily.Pretendard.semiBold.font(size: size)
            $0.textColor = tone == .confirmed ? DSColor.Warning._900 : DSColor.textPrimary
            $0.lineBreakMode = .byTruncatingTail
        }
    }

    /// 접힘의 값 칸. 각인은 한 줄로 넘치면 말줄임.
    private func pill(text: String, tone: ConditionTone, large: Bool) -> UIView {
        let isValue = tone == .confirmed
        let box = UIView().then {
            $0.backgroundColor = isValue ? DSColor.Warning._50 : DSColor.Neutral._100
            $0.layer.cornerRadius = 12
            $0.layer.borderWidth = 1
            $0.layer.borderColor = (isValue ? DSColor.Warning._300 : DSColor.Neutral._200).cgColor
        }
        let label = valueText(text, tone: tone, size: large && isValue ? 14 : 12)
        box.addSubview(label)
        label.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(large ? 2 : 1)
            $0.leading.trailing.equalToSuperview().inset(large ? 8 : 6)
        }
        return box
    }

    /// 구분선 값은 알약 그림으로 — (+)형 · (−)형. 그 외는 글자.
    private func dividingPill(_ c: DividingLineCondition) -> UIView {
        guard case let .value(line) = c, line != .unknown else {
            return pill(text: dividingMenuText(c), tone: c.tone, large: false)
        }
        let box = UIView().then {
            $0.backgroundColor = DSColor.Warning._50
            $0.layer.cornerRadius = 12
            $0.layer.borderWidth = 1
            $0.layer.borderColor = DSColor.Warning._300.cgColor
        }
        let glyph = DividingLineGlyphView(line: line, tint: DSColor.Warning._700)
        box.addSubview(glyph)
        glyph.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(2)
            $0.leading.trailing.equalToSuperview().inset(8)
            $0.width.height.equalTo(14)
        }
        return box
    }

    private func labeled(_ text: String, _ value: UIView) -> UIView {
        UIStackView(arrangedSubviews: [smallLabel(text), value]).then {
            $0.axis = .vertical
            $0.spacing = 3
            $0.alignment = .leading
        }
    }

    private func labeledFill(_ text: String, _ value: UIView) -> UIView {
        UIStackView(arrangedSubviews: [smallLabel(text), value]).then {
            $0.axis = .vertical
            $0.spacing = 3
            $0.alignment = .fill
        }
    }

    /// 펼침의 드롭다운 — 전체면 흰 칸, 값이면 호박색.
    private func dropdown(text: String, tone: ConditionTone, onTap: @escaping (UIView) -> Void) -> UIControl {
        let isValue = tone == .confirmed
        let control = UIControl().then {
            $0.backgroundColor = isValue ? DSColor.Warning._50 : DSColor.surface
            $0.layer.cornerRadius = 7
            $0.layer.borderWidth = 1
            $0.layer.borderColor = (isValue ? DSColor.Warning._300 : DSColor.Neutral._300).cgColor
            $0.isAccessibilityElement = true
            $0.accessibilityTraits = .button
            $0.accessibilityValue = text
        }
        control.addAction(UIAction { _ in onTap(control) }, for: .touchUpInside)
        control.snp.makeConstraints { $0.height.equalTo(30) }
        let label = valueText(text, tone: tone, size: 12)
        let chevron = UIImageView(image: DSIcon.chevronDown.uiImage).then {
            $0.tintColor = isValue ? DSColor.Warning._700 : DSColor.textTertiary
            $0.contentMode = .scaleAspectFit
        }
        control.addSubview(label)
        control.addSubview(chevron)
        label.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview().inset(7)
            $0.trailing.lessThanOrEqualTo(chevron.snp.leading).offset(-2)
        }
        chevron.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().inset(6)
            $0.width.height.equalTo(8)
        }
        return control
    }

    // MARK: 글자

    private func imprintText(_ c: ImprintCondition) -> String {
        switch c {
        case .all:               return "전체"
        case .none:              return "없음"
        case .value(let text, _): return text
        }
    }

    private func imprintMenuText(_ c: ImprintCondition) -> String {
        switch c {
        case .all:   return "전체"
        case .none:  return "없음"
        case .value: return "입력"
        }
    }

    private func dividingMenuText(_ c: DividingLineCondition) -> String {
        switch c {
        case .all:            return "전체"
        case .none:           return "없음"
        case .value(.plus):   return "(+)형"
        case .value(.minus):  return "(−)형"
        case .value(.unknown): return "전체"
        }
    }

    private func markText(_ c: MarkCondition) -> String {
        switch c {
        case .all:     return "전체"
        case .none:    return "없음"
        case .present: return "있음"
        }
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
