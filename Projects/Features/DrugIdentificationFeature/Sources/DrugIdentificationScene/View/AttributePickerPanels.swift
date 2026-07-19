import UIKit
import SnapKit
import Then
import DSKit
import Domain

// MARK: - Color Swatch Mapping

extension PillColorModel {
    /// Exact swatch color per case. `.colorless` / `.unknown` return nil.
    var swatchColor: UIColor? {
        func hex(_ value: UInt32) -> UIColor {
            UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255.0,
                green: CGFloat((value >> 8) & 0xFF) / 255.0,
                blue: CGFloat(value & 0xFF) / 255.0,
                alpha: 1.0
            )
        }
        switch self {
        case .white:      return hex(0xFFFFFF)
        case .yellow:     return hex(0xFACC15)
        case .orange:     return hex(0xFB923C)
        case .pink:       return hex(0xF9A8D4)
        case .red:        return hex(0xEF4444)
        case .brown:      return hex(0x92400E)
        case .lightGreen: return hex(0x86EFAC)
        case .green:      return hex(0x22C55E)
        case .teal:       return hex(0x14B8A6)
        case .blue:       return hex(0x3B82F6)
        case .navy:       return hex(0x1E3A8A)
        case .magenta:    return hex(0xDB2777)
        case .purple:     return hex(0x8B5CF6)
        case .gray:       return hex(0x9CA3AF)
        case .black:      return hex(0x1F2937)
        case .colorless, .unknown: return nil
        }
    }
}

// MARK: - Shape Glyph View

/// Draws a pill shape via CAShapeLayer for a given `PillShapeModel`.
/// Default fill `DSColor.Neutral._400`; recolor via `setTint(_:)`.
final class ShapeGlyphView: UIView {

    private let shape: PillShapeModel
    private let glyph = CAShapeLayer()
    private var fillColor: UIColor = DSColor.Neutral._400

    init(shape: PillShapeModel) {
        self.shape = shape
        super.init(frame: .zero)
        backgroundColor = .clear
        glyph.fillColor = fillColor.cgColor
        glyph.strokeColor = UIColor.clear.cgColor
        layer.addSublayer(glyph)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setTint(_ color: UIColor) {
        fillColor = color
        glyph.fillColor = color.cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        glyph.frame = bounds
        glyph.path = path(in: bounds.insetBy(dx: 1, dy: 1))
    }

    private func path(in r: CGRect) -> CGPath {
        switch shape {
        case .round, .oval:
            // bounds 비율이 이미 원/타원을 결정한다.
            return UIBezierPath(ovalIn: r).cgPath

        case .oblong:
            // 양 끝이 완전히 둥근 스타디움(장방형).
            return UIBezierPath(roundedRect: r, cornerRadius: r.height / 2).cgPath

        case .semicircle:
            // 위 반원 + 아래 평평한 밑변 (반원형).
            let radius = min(r.width / 2, r.height)
            let baseY = r.midY + radius / 2
            let center = CGPoint(x: r.midX, y: baseY)
            let p = UIBezierPath()
            p.addArc(withCenter: center, radius: radius,
                     startAngle: .pi, endAngle: 2 * .pi, clockwise: true)
            p.close()
            return p.cgPath

        case .square:
            return UIBezierPath(roundedRect: r, cornerRadius: min(r.width, r.height) * 0.2).cgPath

        case .triangle: return roundedPolygon(in: r, sides: 3)
        case .diamond:  return roundedPolygon(in: r, sides: 4)
        case .pentagon: return roundedPolygon(in: r, sides: 5)
        case .hexagon:  return roundedPolygon(in: r, sides: 6)
        case .octagon:  return roundedPolygon(in: r, sides: 8)
        case .other, .unknown: return roundedPolygon(in: r, sides: 6)
        }
    }

    // 꼭짓점이 위(12시)를 향하고 모서리가 둥근 정n각형. (Pencil polygon 기본 방향과 일치)
    private func roundedPolygon(in r: CGRect) -> CGPath { roundedPolygon(in: r, sides: 6) }

    private func roundedPolygon(in r: CGRect, sides: Int) -> CGPath {
        let center = CGPoint(x: r.midX, y: r.midY)
        let radius = min(r.width, r.height) / 2
        let corner = radius * 0.18
        let verts: [CGPoint] = (0..<sides).map { i in
            let a = -.pi / 2 + CGFloat(i) * 2 * .pi / CGFloat(sides)
            return CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
        }
        let path = UIBezierPath()
        for i in 0..<sides {
            let curr = verts[i]
            let prev = verts[(i + sides - 1) % sides]
            let next = verts[(i + 1) % sides]
            let toPrev = unit(from: curr, to: prev)
            let toNext = unit(from: curr, to: next)
            let cr = min(corner, dist(curr, prev) / 2, dist(curr, next) / 2)
            let p1 = CGPoint(x: curr.x + toPrev.dx * cr, y: curr.y + toPrev.dy * cr)
            let p2 = CGPoint(x: curr.x + toNext.dx * cr, y: curr.y + toNext.dy * cr)
            if i == 0 { path.move(to: p1) } else { path.addLine(to: p1) }
            path.addQuadCurve(to: p2, controlPoint: curr)
        }
        path.close()
        return path.cgPath
    }

    private func unit(from a: CGPoint, to b: CGPoint) -> CGVector {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(0.0001, sqrt(dx * dx + dy * dy))
        return CGVector(dx: dx / len, dy: dy / len)
    }
    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
    }
}

// MARK: - Color Picker Panel

/// Grid of 16 color swatches (2 rows of 8) with a multi-select hint.
final class ColorPickerPanel: UIView {

    /// 다중 선택 — 탭할 때마다 토글되고, 현재 선택된 전체 색 배열을 전달한다.
    var onSelectionChanged: (([PillColorModel]) -> Void)?

    /// Source-compat shim: transparency now lives in `TransparencyRowView`.
    /// Kept so existing callers still compile; the panel itself never fires it.
    var onTransparent: ((Bool) -> Void)?

    private struct SwatchCell {
        let model: PillColorModel
        let container: UIControl
        let swatch: UIView
        let slashLayer: CAShapeLayer?
        let label: UILabel
    }

    private let ordered: [PillColorModel] = [
        .white, .yellow, .orange, .pink, .red, .brown, .lightGreen, .green,
        .teal, .blue, .navy, .magenta, .purple, .gray, .black, .colorless
    ]

    private let displayLabels: [PillColorModel: String] = [
        .white: "하양", .yellow: "노랑", .orange: "주황", .pink: "분홍",
        .red: "빨강", .brown: "갈색", .lightGreen: "연두", .green: "초록",
        .teal: "청록", .blue: "파랑", .navy: "남색", .magenta: "자주",
        .purple: "보라", .gray: "회색", .black: "검정", .colorless: "무색"
    ]

    private var cells: [SwatchCell] = []
    /// 탭 순서를 유지하는 선택 목록 (칩 요약에서 첫 색을 대표로 쓴다).
    private var selectedColors: [PillColorModel] = []

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        backgroundColor = DSColor.Neutral._100
        layer.cornerRadius = 12
        layer.masksToBounds = true

        let hint = UILabel().then {
            $0.text = "여러 색을 선택할 수 있어요"
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
            $0.textColor = DSColor.textTertiary
        }

        let grid = UIStackView().then {
            $0.axis = .vertical
            $0.spacing = 9
        }
        for row in ordered.chunked(into: 8) {
            let rowStack = UIStackView().then {
                $0.axis = .horizontal
                $0.spacing = 4
                $0.distribution = .fillEqually
                $0.alignment = .top
            }
            for model in row {
                rowStack.addArrangedSubview(makeSwatchCell(model))
            }
            grid.addArrangedSubview(rowStack)
        }

        let stack = UIStackView(arrangedSubviews: [hint, grid]).then {
            $0.axis = .vertical
            $0.spacing = 9
        }
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(12) }
    }

    private func makeSwatchCell(_ model: PillColorModel) -> UIView {
        let container = UIControl()

        let swatch = UIView().then {
            $0.layer.cornerRadius = 8
            $0.layer.borderWidth = 1
            $0.layer.borderColor = DSColor.Neutral._200.cgColor
            $0.isUserInteractionEnabled = false
        }

        var slashLayer: CAShapeLayer?
        if model == .colorless {
            swatch.backgroundColor = .white
            let slash = CAShapeLayer()
            slash.strokeColor = DSColor.Neutral._400.cgColor
            slash.lineWidth = 2
            slash.fillColor = UIColor.clear.cgColor
            slash.lineCap = .round
            swatch.layer.addSublayer(slash)
            slashLayer = slash
        } else {
            swatch.backgroundColor = model.swatchColor ?? .white
        }

        let label = UILabel().then {
            $0.text = displayLabels[model]
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 9)
            $0.textColor = DSColor.textTertiary
            $0.textAlignment = .center
        }

        let stack = UIStackView(arrangedSubviews: [swatch, label]).then {
            $0.axis = .vertical
            $0.spacing = 4
            $0.alignment = .center
            $0.isUserInteractionEnabled = false
        }
        container.addSubview(stack)
        swatch.snp.makeConstraints { $0.width.height.equalTo(30) }
        stack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.centerX.equalToSuperview()
            $0.leading.greaterThanOrEqualToSuperview()
            $0.trailing.lessThanOrEqualToSuperview()
        }

        container.addAction(UIAction { [weak self] _ in
            self?.handleTap(model)
        }, for: .touchUpInside)

        cells.append(SwatchCell(model: model,
                                container: container,
                                swatch: swatch,
                                slashLayer: slashLayer,
                                label: label))
        return container
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Update the diagonal slash path for the colorless swatch (bottom-left → top-right).
        for cell in cells where cell.slashLayer != nil {
            let b = cell.swatch.bounds
            cell.slashLayer?.frame = b
            let inset: CGFloat = 5
            let p = UIBezierPath()
            p.move(to: CGPoint(x: inset, y: b.height - inset))
            p.addLine(to: CGPoint(x: b.width - inset, y: inset))
            cell.slashLayer?.path = p.cgPath
        }
    }

    private func handleTap(_ model: PillColorModel) {
        if let index = selectedColors.firstIndex(of: model) {
            selectedColors.remove(at: index)
        } else {
            selectedColors.append(model)
        }
        applyHighlights()
        onSelectionChanged?(selectedColors)
    }

    /// Highlights the given colors (idempotent, safe before/after layout).
    func setSelected(_ colors: [PillColorModel]) {
        selectedColors = colors
        applyHighlights()
    }

    private func applyHighlights() {
        for cell in cells {
            let on = selectedColors.contains(cell.model)
            cell.swatch.layer.borderColor = (on ? DSColor.Primary._500 : DSColor.Neutral._200).cgColor
            cell.swatch.layer.borderWidth = on ? 2.5 : 1
            cell.label.textColor = on ? DSColor.Primary._600 : DSColor.textTertiary
            cell.label.font = on
                ? DSKitFontFamily.Pretendard.semiBold.font(size: 9)
                : DSKitFontFamily.Pretendard.regular.font(size: 9)
        }
    }
}

// MARK: - Transparency Row View

/// A titled row with a trailing switch for "투명 여부".
final class TransparencyRowView: UIView {

    var onToggle: ((Bool) -> Void)?

    private let toggle = UISwitch()

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        let title = UILabel().then {
            $0.text = "투명 여부"
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 14)
            $0.textColor = DSColor.textSecondary
        }
        let subtitle = UILabel().then {
            $0.text = "빛이 비치는 반투명·투명 재질"
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
            $0.textColor = DSColor.textTertiary
        }
        let textStack = UIStackView(arrangedSubviews: [title, subtitle]).then {
            $0.axis = .vertical
            $0.spacing = 2
            $0.alignment = .leading
        }

        toggle.onTintColor = DSColor.Primary._500
        toggle.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        toggle.setContentHuggingPriority(.required, for: .horizontal)
        toggle.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [textStack, UIView(), toggle]).then {
            $0.axis = .horizontal
            $0.alignment = .center
        }
        addSubview(row)
        row.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    @objc private func switchChanged() {
        onToggle?(toggle.isOn)
    }

    /// Sets the switch state without firing `onToggle`.
    func setOn(_ on: Bool) {
        toggle.setOn(on, animated: false)
    }
}

// MARK: - Shape Picker Panel

/// 3 rows of shape cells (11 shapes; last row has a trailing spacer).
final class ShapePickerPanel: UIView {

    var onSelect: ((PillShapeModel) -> Void)?

    private struct ShapeCell {
        let model: PillShapeModel
        let container: UIControl
        let glyph: ShapeGlyphView?
        let imageView: UIImageView?
        let label: UILabel
    }

    private let ordered: [PillShapeModel] = [
        .round, .oval, .oblong, .semicircle,
        .triangle, .square, .diamond, .pentagon,
        .hexagon, .octagon, .other
    ]

    private let displayLabels: [PillShapeModel: String] = [
        .round: "원형", .oval: "타원형", .oblong: "장방형", .semicircle: "반원형",
        .triangle: "삼각형", .square: "사각형", .diamond: "마름모형", .pentagon: "오각형",
        .hexagon: "육각형", .octagon: "팔각형", .other: "기타"
    ]

    // Approximate per-shape glyph size (width x height), kept <= ~26 tall.
    private func glyphSize(for shape: PillShapeModel) -> CGSize {
        switch shape {
        case .round:      return CGSize(width: 19, height: 19)
        case .oval:       return CGSize(width: 23, height: 14)
        case .oblong:     return CGSize(width: 24, height: 12)
        case .semicircle: return CGSize(width: 23, height: 13)
        case .triangle:   return CGSize(width: 26, height: 23)
        case .square:     return CGSize(width: 18, height: 18)
        case .diamond:    return CGSize(width: 24, height: 24)
        case .pentagon:   return CGSize(width: 21, height: 21)
        case .hexagon:    return CGSize(width: 21, height: 21)
        case .octagon:    return CGSize(width: 20, height: 20)
        case .other, .unknown: return CGSize(width: 22, height: 20)
        }
    }

    private var cells: [ShapeCell] = []

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        backgroundColor = DSColor.Neutral._100
        layer.cornerRadius = 12
        layer.masksToBounds = true

        let grid = UIStackView().then {
            $0.axis = .vertical
            $0.spacing = 8
        }
        for row in ordered.chunked(into: 4) {
            let rowStack = UIStackView().then {
                $0.axis = .horizontal
                $0.spacing = 8
                $0.distribution = .fillEqually
                $0.alignment = .fill
            }
            for model in row {
                rowStack.addArrangedSubview(makeCell(model))
            }
            // Fill trailing empty slots with plain spacers.
            for _ in row.count..<4 {
                rowStack.addArrangedSubview(UIView())
            }
            grid.addArrangedSubview(rowStack)
        }
        addSubview(grid)
        grid.snp.makeConstraints { $0.edges.equalToSuperview().inset(12) }
    }

    private func makeCell(_ model: PillShapeModel) -> UIView {
        let container = UIControl().then {
            $0.backgroundColor = DSColor.Neutral._0
            $0.layer.cornerRadius = 10
            $0.layer.borderWidth = 1
            $0.layer.borderColor = DSColor.Neutral._200.cgColor
        }

        let glyphContainer = UIView()
        var glyph: ShapeGlyphView?
        var imageView: UIImageView?

        if model == .other {
            let iv = UIImageView().then {
                $0.image = UIImage(systemName: "square.on.circle")
                $0.tintColor = DSColor.Neutral._400
                $0.contentMode = .scaleAspectFit
            }
            glyphContainer.addSubview(iv)
            iv.snp.makeConstraints {
                $0.center.equalToSuperview()
                $0.width.height.equalTo(22)
            }
            imageView = iv
        } else {
            let g = ShapeGlyphView(shape: model)
            glyphContainer.addSubview(g)
            let size = glyphSize(for: model)
            g.snp.makeConstraints {
                $0.center.equalToSuperview()
                $0.width.equalTo(size.width)
                $0.height.equalTo(size.height)
            }
            glyph = g
        }
        glyphContainer.snp.makeConstraints {
            $0.width.equalTo(32)
            $0.height.equalTo(28)
        }

        let label = UILabel().then {
            $0.text = displayLabels[model]
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 11)
            $0.textColor = DSColor.textSecondary
            $0.textAlignment = .center
        }

        let stack = UIStackView(arrangedSubviews: [glyphContainer, label]).then {
            $0.axis = .vertical
            $0.spacing = 5
            $0.alignment = .center
            $0.isUserInteractionEnabled = false
        }
        container.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(8)
            $0.leading.trailing.equalToSuperview().inset(4)
        }

        container.addAction(UIAction { [weak self] _ in
            self?.setSelected(model)
            self?.onSelect?(model)
        }, for: .touchUpInside)

        cells.append(ShapeCell(model: model,
                               container: container,
                               glyph: glyph,
                               imageView: imageView,
                               label: label))
        return container
    }

    /// Highlights the given shape (idempotent, safe before/after layout).
    func setSelected(_ shape: PillShapeModel?) {
        for cell in cells {
            let on = cell.model == shape
            cell.container.backgroundColor = on ? DSColor.Primary._50 : DSColor.Neutral._0
            cell.container.layer.borderWidth = on ? 1.5 : 1
            cell.container.layer.borderColor = (on ? DSColor.Primary._500 : DSColor.Neutral._200).cgColor
            let tint = on ? DSColor.Primary._500 : DSColor.Neutral._400
            cell.glyph?.setTint(tint)
            cell.imageView?.tintColor = tint
            cell.label.textColor = on ? DSColor.Primary._600 : DSColor.textSecondary
            cell.label.font = on
                ? DSKitFontFamily.Pretendard.semiBold.font(size: 11)
                : DSKitFontFamily.Pretendard.regular.font(size: 11)
        }
    }
}

// MARK: - Formulation Icon View

/// Draws a formulation icon (tablet / hard capsule / soft capsule) that is recolorable.
final class FormulationIconView: UIView {

    private let formulation: PillFormulationModel
    private var shapeLayers: [CAShapeLayer] = []
    private let glossLayer = CAShapeLayer()
    private var tint: UIColor = DSColor.Neutral._400

    init(formulation: PillFormulationModel) {
        self.formulation = formulation
        super.init(frame: .zero)
        backgroundColor = .clear
        setupLayers()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupLayers() {
        switch formulation {
        case .tablet:
            let disc = CAShapeLayer()
            disc.fillColor = tint.cgColor
            let score = CAShapeLayer()
            score.strokeColor = DSColor.Neutral._0.cgColor
            score.lineWidth = 1.5
            score.fillColor = UIColor.clear.cgColor
            layer.addSublayer(disc)
            layer.addSublayer(score)
            shapeLayers = [disc, score]

        case .hardCapsule:
            let body = CAShapeLayer()
            body.fillColor = tint.cgColor
            let joint = CAShapeLayer()
            joint.strokeColor = DSColor.Neutral._0.cgColor
            joint.lineWidth = 1.5
            joint.fillColor = UIColor.clear.cgColor
            layer.addSublayer(body)
            layer.addSublayer(joint)
            shapeLayers = [body, joint]

        case .softCapsule:
            let body = CAShapeLayer()
            body.fillColor = tint.cgColor
            glossLayer.fillColor = DSColor.Neutral._0.cgColor
            glossLayer.opacity = 0.85
            layer.addSublayer(body)
            layer.addSublayer(glossLayer)
            shapeLayers = [body]

        case .other, .unknown:
            break
        }
    }

    func setTint(_ color: UIColor) {
        tint = color
        // Only the primary (index 0) fill uses the tint; scores/joints stay Neutral._0.
        shapeLayers.first?.fillColor = color.cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let r = bounds.insetBy(dx: 1, dy: 1)

        switch formulation {
        case .tablet:
            let d = min(r.width, r.height)
            let box = CGRect(x: r.midX - d / 2, y: r.midY - d / 2, width: d, height: d)
            shapeLayers[0].path = UIBezierPath(ovalIn: box).cgPath
            let score = UIBezierPath()
            score.move(to: CGPoint(x: box.minX + box.width * 0.18, y: box.midY))
            score.addLine(to: CGPoint(x: box.maxX - box.width * 0.18, y: box.midY))
            shapeLayers[1].path = score.cgPath

        case .hardCapsule:
            let h = min(r.height, r.width * 0.55)
            let box = CGRect(x: r.minX, y: r.midY - h / 2, width: r.width, height: h)
            shapeLayers[0].path = UIBezierPath(roundedRect: box, cornerRadius: h / 2).cgPath
            let joint = UIBezierPath()
            joint.move(to: CGPoint(x: box.midX, y: box.minY + box.height * 0.15))
            joint.addLine(to: CGPoint(x: box.midX, y: box.maxY - box.height * 0.15))
            shapeLayers[1].path = joint.cgPath

        case .softCapsule:
            let box = r.insetBy(dx: 0, dy: r.height * 0.18)
            shapeLayers[0].path = UIBezierPath(ovalIn: box).cgPath
            let glossW = box.width * 0.28
            let glossH = box.height * 0.28
            let glossBox = CGRect(x: box.minX + box.width * 0.20,
                                  y: box.minY + box.height * 0.20,
                                  width: glossW, height: glossH)
            glossLayer.path = UIBezierPath(ovalIn: glossBox).cgPath

        case .other, .unknown:
            break
        }
    }
}

// MARK: - Formulation Picker Panel

/// A single row of 4 formulation cells.
final class FormulationPickerPanel: UIView {

    var onSelect: ((PillFormulationModel) -> Void)?

    private struct FormulationCell {
        let model: PillFormulationModel
        let container: UIControl
        let icon: FormulationIconView?
        let imageView: UIImageView?
        let label: UILabel
    }

    private let ordered: [PillFormulationModel] = [.tablet, .hardCapsule, .softCapsule, .other]

    private let displayLabels: [PillFormulationModel: String] = [
        .tablet: "정제", .hardCapsule: "경질캡슐", .softCapsule: "연질캡슐", .other: "기타"
    ]

    private var cells: [FormulationCell] = []

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        backgroundColor = DSColor.Neutral._100
        layer.cornerRadius = 12
        layer.masksToBounds = true

        let row = UIStackView().then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.distribution = .fillEqually
            $0.alignment = .fill
        }
        for model in ordered {
            row.addArrangedSubview(makeCell(model))
        }
        addSubview(row)
        row.snp.makeConstraints { $0.edges.equalToSuperview().inset(12) }
    }

    private func makeCell(_ model: PillFormulationModel) -> UIView {
        let container = UIControl().then {
            $0.backgroundColor = DSColor.Neutral._0
            $0.layer.cornerRadius = 10
            $0.layer.borderWidth = 1
            $0.layer.borderColor = DSColor.Neutral._200.cgColor
        }

        let iconContainer = UIView()
        var icon: FormulationIconView?
        var imageView: UIImageView?

        if model == .other {
            let iv = UIImageView().then {
                $0.image = UIImage(systemName: "ellipsis")
                $0.tintColor = DSColor.Neutral._400
                $0.contentMode = .scaleAspectFit
            }
            iconContainer.addSubview(iv)
            iv.snp.makeConstraints {
                $0.center.equalToSuperview()
                $0.width.equalTo(24)
                $0.height.equalTo(20)
            }
            imageView = iv
        } else {
            let v = FormulationIconView(formulation: model)
            iconContainer.addSubview(v)
            v.snp.makeConstraints { $0.edges.equalToSuperview() }
            icon = v
        }
        iconContainer.snp.makeConstraints {
            $0.width.equalTo(28)
            $0.height.equalTo(24)
        }

        let label = UILabel().then {
            $0.text = displayLabels[model]
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 11)
            $0.textColor = DSColor.textSecondary
            $0.textAlignment = .center
            $0.adjustsFontSizeToFitWidth = true
            $0.minimumScaleFactor = 0.8
        }

        let stack = UIStackView(arrangedSubviews: [iconContainer, label]).then {
            $0.axis = .vertical
            $0.spacing = 5
            $0.alignment = .center
            $0.isUserInteractionEnabled = false
        }
        container.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(10)
            $0.leading.trailing.equalToSuperview().inset(4)
        }

        container.addAction(UIAction { [weak self] _ in
            self?.setSelected(model)
            self?.onSelect?(model)
        }, for: .touchUpInside)

        cells.append(FormulationCell(model: model,
                                     container: container,
                                     icon: icon,
                                     imageView: imageView,
                                     label: label))
        return container
    }

    /// Highlights the given formulation (idempotent, safe before/after layout).
    func setSelected(_ formulation: PillFormulationModel?) {
        for cell in cells {
            let on = cell.model == formulation
            cell.container.backgroundColor = on ? DSColor.Primary._50 : DSColor.Neutral._0
            cell.container.layer.borderWidth = on ? 1.5 : 1
            cell.container.layer.borderColor = (on ? DSColor.Primary._500 : DSColor.Neutral._200).cgColor
            let tint = on ? DSColor.Primary._500 : DSColor.Neutral._400
            cell.icon?.setTint(tint)
            cell.imageView?.tintColor = tint
            cell.label.textColor = on ? DSColor.Primary._600 : DSColor.textSecondary
            cell.label.font = on
                ? DSKitFontFamily.Pretendard.semiBold.font(size: 11)
                : DSKitFontFamily.Pretendard.regular.font(size: 11)
        }
    }
}

// MARK: - Array Chunk Helper

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
