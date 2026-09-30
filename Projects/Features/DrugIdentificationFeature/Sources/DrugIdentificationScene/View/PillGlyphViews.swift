import UIKit
import SnapKit
import Then
import DSKit
import Domain

// 알약 모양 · 제형 그림. 색상 팔레트(PillColorModel.swatchColor)는 PillColorSwatch.swift 참고.

// MARK: - Shape Glyph View

/// 알약 모양 글리프 — 디자인(DESIGN.pen NM-490 ⑧-c 모양 메뉴)의 크기 · 모서리 반경을 코드로 그린다.
///
/// 디자인에서 뽑은 PDF 는 둥근 다각형이 제 테두리 밖으로 나가 잘려서 쓰지 않는다.
/// 박스 안에 모양 고유 비율로 맞춰(aspect fit) 그리므로 원은 원 · 타원은 타원으로 유지된다.
/// `기타` 만 선 아이콘(lucide shapes) 에셋이다. 기본색 `DSColor.Neutral._400`, `setTint(_:)`로 변경.
final class ShapeGlyphView: UIView {

    private let shape: PillShapeModel
    private let atDesignSize: Bool
    private let shapeLayer = CAShapeLayer()
    private let otherImageView = UIImageView()
    private var tint: UIColor = DSColor.Neutral._400

    /// - Parameter atDesignSize: 박스에 맞춰 키우지 않고 디자인 크기 그대로 가운데 그린다(메뉴 칸 32×28).
    ///   false 면 박스에 꽉 맞춘다(칩처럼 작은 자리).
    init(shape: PillShapeModel, atDesignSize: Bool = false) {
        self.shape = shape
        self.atDesignSize = atDesignSize
        super.init(frame: .zero)
        backgroundColor = .clear
        if shape.spec == nil {
            otherImageView.contentMode = .scaleAspectFit
            otherImageView.image = UIImage(named: "PillShapes/other", in: .module, compatibleWith: nil)?
                .withRenderingMode(.alwaysTemplate)
            addSubview(otherImageView)
            otherImageView.snp.makeConstraints {
                if atDesignSize {
                    $0.center.equalToSuperview()
                    $0.width.height.equalTo(20)
                } else {
                    $0.edges.equalToSuperview()
                }
            }
        } else {
            layer.addSublayer(shapeLayer)
        }
        setTint(DSColor.Neutral._400)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setTint(_ color: UIColor) {
        tint = color
        shapeLayer.fillColor = color.resolvedColor(with: traitCollection).cgColor
        otherImageView.tintColor = color
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let spec = shape.spec, bounds.width > 0, bounds.height > 0 else { return }
        let fit = min(bounds.width / spec.size.width, bounds.height / spec.size.height)
        let scale = atDesignSize ? min(1, fit) : fit
        let size = CGSize(width: spec.size.width * scale, height: spec.size.height * scale)
        let box = CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2,
                         width: size.width, height: size.height)
        shapeLayer.path = spec.kind.path(in: box, cornerRadius: spec.cornerRadius * scale)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // CGColor 는 다크 모드를 따라가지 않는다 — 지금 모드로 다시 푼다.
        shapeLayer.fillColor = tint.resolvedColor(with: traitCollection).cgColor
    }
}

private struct ShapeSpec {
    enum Kind {
        case ellipse
        case roundedRect
        /// 위쪽 두 모서리만 둥근 사각형(반원형).
        case topRounded
        /// 정다각형 — 꼭짓점 수 · 첫 꼭짓점 각도(0 = 위).
        case polygon(sides: Int, rotation: CGFloat)

        func path(in box: CGRect, cornerRadius r: CGFloat) -> CGPath {
            switch self {
            case .ellipse:
                return CGPath(ellipseIn: box, transform: nil)
            case .roundedRect:
                return UIBezierPath(roundedRect: box, cornerRadius: r).cgPath
            case .topRounded:
                return UIBezierPath(roundedRect: box, byRoundingCorners: [.topLeft, .topRight],
                                    cornerRadii: CGSize(width: r, height: r)).cgPath
            case .polygon(let sides, let rotation):
                return Self.roundedPolygon(sides: sides, rotation: rotation, in: box, cornerRadius: r)
            }
        }

        /// 정다각형 꼭짓점을 박스에 꽉 차게 늘린 뒤, 꼭짓점마다 반경 r 로 둥글린다.
        private static func roundedPolygon(sides: Int, rotation: CGFloat, in box: CGRect, cornerRadius r: CGFloat) -> CGPath {
            let unit = (0..<sides).map { i -> CGPoint in
                let angle = -CGFloat.pi / 2 + rotation + CGFloat(i) * 2 * .pi / CGFloat(sides)
                return CGPoint(x: cos(angle), y: sin(angle))
            }
            let minX = unit.map(\.x).min()!, maxX = unit.map(\.x).max()!
            let minY = unit.map(\.y).min()!, maxY = unit.map(\.y).max()!
            let points = unit.map {
                CGPoint(x: box.minX + ($0.x - minX) / (maxX - minX) * box.width,
                        y: box.minY + ($0.y - minY) / (maxY - minY) * box.height)
            }
            let path = CGMutablePath()
            let last = points[sides - 1], first = points[0]
            path.move(to: CGPoint(x: (last.x + first.x) / 2, y: (last.y + first.y) / 2))
            for i in 0..<sides {
                path.addArc(tangent1End: points[i], tangent2End: points[(i + 1) % sides], radius: r)
            }
            path.closeSubpath()
            return path
        }
    }

    /// 디자인 모양 메뉴의 그림 크기(pt) — 비율과 모서리 반경의 기준.
    let size: CGSize
    let cornerRadius: CGFloat
    let kind: Kind
}

private extension PillShapeModel {
    /// nil = `기타`(선 아이콘 에셋).
    var spec: ShapeSpec? {
        switch self {
        case .round:      return ShapeSpec(size: CGSize(width: 19, height: 19), cornerRadius: 0, kind: .ellipse)
        case .oval:       return ShapeSpec(size: CGSize(width: 23, height: 14), cornerRadius: 0, kind: .ellipse)
        case .oblong:     return ShapeSpec(size: CGSize(width: 24, height: 12), cornerRadius: 6, kind: .roundedRect)
        case .semicircle: return ShapeSpec(size: CGSize(width: 23, height: 13), cornerRadius: 11, kind: .topRounded)
        case .triangle:   return ShapeSpec(size: CGSize(width: 26, height: 23), cornerRadius: 3, kind: .polygon(sides: 3, rotation: 0))
        case .square:     return ShapeSpec(size: CGSize(width: 17, height: 17), cornerRadius: 4, kind: .roundedRect)
        case .diamond:    return ShapeSpec(size: CGSize(width: 24, height: 24), cornerRadius: 3, kind: .polygon(sides: 4, rotation: 0))
        case .pentagon:   return ShapeSpec(size: CGSize(width: 21, height: 21), cornerRadius: 3, kind: .polygon(sides: 5, rotation: 0))
        case .hexagon:    return ShapeSpec(size: CGSize(width: 20, height: 20), cornerRadius: 3, kind: .polygon(sides: 6, rotation: 0))
        case .octagon:    return ShapeSpec(size: CGSize(width: 19, height: 19), cornerRadius: 2, kind: .polygon(sides: 8, rotation: .pi / 8))
        case .other, .unknown: return nil
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
