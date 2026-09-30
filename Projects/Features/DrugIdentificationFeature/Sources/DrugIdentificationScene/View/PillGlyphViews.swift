import UIKit
import SnapKit
import Then
import DSKit
import Domain

// 알약 모양 · 제형 그림. 색상 팔레트(PillColorModel.swatchColor)는 PillColorSwatch.swift 참고.

// MARK: - Shape Glyph View

/// 알약 모양 글리프. 디자인에서 추출한 벡터 아이콘(Assets/PillShapes)을 템플릿으로 틴트해 그린다.
///
/// 이미지가 모양 고유 비율을 갖고 있고 `scaleAspectFit`으로 그리므로,
/// 박스가 정사각이든 가로로 길든 원은 원·타원은 타원으로 유지된다(늘어나지 않는다).
/// 기본색 `DSColor.Neutral._400`, `setTint(_:)`로 변경.
final class ShapeGlyphView: UIView {

    private let imageView = UIImageView()

    init(shape: PillShapeModel) {
        super.init(frame: .zero)
        backgroundColor = .clear
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = DSColor.Neutral._400
        imageView.image = shape.glyphImage
        addSubview(imageView)
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setTint(_ color: UIColor) {
        imageView.tintColor = color
    }
}

private extension PillShapeModel {
    /// PillShapes 에셋의 템플릿 이미지. `.unknown` 은 '기타'로 대체.
    var glyphImage: UIImage? {
        let name: String
        switch self {
        case .round:      name = "round"
        case .oval:       name = "oval"
        case .oblong:     name = "oblong"
        case .semicircle: name = "semicircle"
        case .square:     name = "square"
        case .triangle:   name = "triangle"
        case .diamond:    name = "diamond"
        case .pentagon:   name = "pentagon"
        case .hexagon:    name = "hexagon"
        case .octagon:    name = "octagon"
        case .other, .unknown: name = "other"
        }
        return UIImage(named: "PillShapes/\(name)", in: .module, compatibleWith: nil)?
            .withRenderingMode(.alwaysTemplate)
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
