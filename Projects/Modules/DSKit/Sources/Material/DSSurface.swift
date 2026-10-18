import UIKit

// MARK: - Shadow
// 디자인(Pencil)의 그림자 한 겹. blur는 디자인 값 그대로 받고, CALayer에는 절반을 shadowRadius로 준다.

public struct DSShadow {

    public let color: UIColor
    public let offset: CGSize
    public let blur: CGFloat
    /// true면 면 안쪽에 드리운다(안쪽 그림자).
    public let isInner: Bool

    public init(color: UIColor, x: CGFloat = 0, y: CGFloat = 0, blur: CGFloat, isInner: Bool = false) {
        self.color = color
        self.offset = CGSize(width: x, height: y)
        self.blur = blur
        self.isInner = isInner
    }
}

// MARK: - Surface Spec
// 면 하나를 그리는 데 필요한 값 묶음 — 칠(여러 겹) · 테두리 · 그림자 · 배경 흐림.
// V2.1.0 재질 세 가지(유리 · 볼록 · 평면)는 아래 프리셋으로 둔다. 근거는 NM-580.

public struct DSSurfaceSpec {

    public enum Paint {
        case solid(UIColor)
        /// angle은 디자인 기준 각도 — 180 = 위→아래, 135 = 왼쪽 위→오른쪽 아래.
        case linear([(UIColor, CGFloat)], angle: CGFloat)
        /// center · radius는 면 크기에 대한 비율.
        case radial([(UIColor, CGFloat)], center: CGPoint, radius: CGFloat)
    }

    public var fills: [Paint]
    public var stroke: Paint?
    public var strokeWidth: CGFloat
    public var shadows: [DSShadow]
    /// 뒤 화면을 흐린다(뜨는 면). '투명도 줄이기'가 켜져 있으면 `glassFloatingFallback`으로 그린다.
    public var blursBackground: Bool

    public init(
        fills: [Paint],
        stroke: Paint? = nil,
        strokeWidth: CGFloat = 1,
        shadows: [DSShadow] = [],
        blursBackground: Bool = false
    ) {
        self.fills = fills
        self.stroke = stroke
        self.strokeWidth = strokeWidth
        self.shadows = shadows
        self.blursBackground = blursBackground
    }
}

// MARK: - Tokens
// DESIGN.pen V2.1.0 변수(glass-* · raised-* · shadow-*). 알파가 들어간 색이라 에셋 카탈로그 대신 코드에 둔다.

enum DSMaterialToken {

    static func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    private static let white = UIColor.white
    private static let ink: UInt32 = 0x0F172A

    // 유리
    static let glassFillTop = white.withAlphaComponent(0.55)
    static let glassFillBottom = white.withAlphaComponent(0.30)
    static let glassHighlight = white.withAlphaComponent(0.80)
    static let glassSheen = white.withAlphaComponent(0.45)
    static let glassStrokeSky = rgb(0xE0F2FE, 0.50)
    static let glassStrokeClear = white.withAlphaComponent(0.20)
    static let glassStrokeAmber = rgb(0xFDE68A, 0.25)
    static let glassInnerGlow = white.withAlphaComponent(0.70)
    static let glassInnerShade = rgb(0x475569, 0.15)
    static let glassFallback = white.withAlphaComponent(0.92)
    static let glassTintPrimaryTop = rgb(0x0EA5E9, 0.92)
    static let glassTintPrimaryBottom = rgb(0x0EA5E9, 0.85)
    static let glassStrokeWidth: CGFloat = 1.8
    static let glassStrokeWidthSmall: CGFloat = 1.2

    // 볼록
    static let raisedNeutralBottom = rgb(0xF6F8FA)
    static let raisedHighlight = white.withAlphaComponent(0.20)
    static let raisedPrimary = (top: rgb(0x16AAEA), bottom: rgb(0x0B9CDE), shadow: rgb(0x0284C7, 0.20))
    static let raisedCaution = (top: rgb(0xE27934), bottom: rgb(0xD76D29), shadow: rgb(0xC65F1E, 0.20))
    static let raisedError = (top: rgb(0xF04A4A), bottom: rgb(0xE63E3E), shadow: rgb(0xDC2626, 0.20))

    // 그림자
    static let shadowCard = DSShadow(color: rgb(ink, 0.12), y: 14, blur: 34)
    static let shadowCardContact = DSShadow(color: rgb(ink, 0.10), y: 1, blur: 2)
    static let shadowList = DSShadow(color: rgb(ink, 0.09), y: 8, blur: 22)
    static let shadowListContact = DSShadow(color: rgb(ink, 0.08), y: 1, blur: 2)
    static let shadowSmall = DSShadow(color: rgb(ink, 0.08), y: 2, blur: 6)

    // 유리 안쪽 그림자 — 왼쪽 위 빛 테두리 · 안쪽 빛 · 오른쪽 아래 그늘
    static let innerEdge = DSShadow(color: white, x: 1.5, y: 2, blur: 1, isInner: true)
    static func innerGlow(_ blur: CGFloat) -> DSShadow {
        DSShadow(color: glassInnerGlow, blur: blur, isInner: true)
    }
    static let innerShade = DSShadow(color: glassInnerShade, x: -2, y: -3, blur: 8, isInner: true)
    /// 볼록 면 윗변의 1pt 빛
    static let raisedTopEdge = DSShadow(color: white, y: 1, blur: 0, isInner: true)
    static let raisedTopHighlight = DSShadow(color: raisedHighlight, y: 1, blur: 0, isInner: true)

    static let glassFill: [DSSurfaceSpec.Paint] = [
        .linear([(glassFillTop, 0), (glassFillBottom, 1)], angle: 180),
        .radial([(glassHighlight, 0), (white.withAlphaComponent(0), 1)], center: CGPoint(x: 0.08, y: 0.05), radius: 0.9)
    ]
    static let glassSheenFill: DSSurfaceSpec.Paint = .linear(
        [(white.withAlphaComponent(0), 0.35), (glassSheen, 0.48), (white.withAlphaComponent(0), 0.6)],
        angle: 120
    )
    static let glassStroke: DSSurfaceSpec.Paint = .linear(
        [(white, 0), (glassStrokeSky, 0.25), (glassStrokeClear, 0.45), (glassStrokeAmber, 0.7), (white, 1)],
        angle: 135
    )
    static let tintedHighlight: DSSurfaceSpec.Paint = .radial(
        [(white.withAlphaComponent(0.7), 0), (white.withAlphaComponent(0), 1)],
        center: CGPoint(x: 0.08, y: 0.05),
        radius: 0.9
    )
}

// MARK: - Presets

extension DSSurfaceSpec {

    private typealias T = DSMaterialToken

    // MARK: 유리

    /// 카드 — 홈 카드, 결과 카드 등 큰 면
    public static let glassCard = DSSurfaceSpec(
        fills: T.glassFill + [T.glassSheenFill],
        stroke: T.glassStroke,
        strokeWidth: T.glassStrokeWidth,
        shadows: [T.shadowCard, T.shadowCardContact, T.innerEdge, T.innerGlow(14), T.innerShade]
    )

    /// 목록 카드 — 한 줄 행
    public static let glassListCard = DSSurfaceSpec(
        fills: T.glassFill,
        stroke: T.glassStroke,
        strokeWidth: T.glassStrokeWidth,
        shadows: [T.shadowList, T.shadowListContact, T.innerEdge, T.innerGlow(12)]
    )

    /// 뜨는 면 — 탭 바, 띄운 조작부
    public static let glassFloating = DSSurfaceSpec(
        fills: T.glassFill + [T.glassSheenFill],
        stroke: T.glassStroke,
        strokeWidth: T.glassStrokeWidth,
        shadows: [T.shadowCard, T.shadowCardContact, T.innerEdge, T.innerGlow(14), T.innerShade],
        blursBackground: true
    )

    /// 뜨는 면의 대체 — 흐림을 못 쓸 때('투명도 줄이기')
    public static let glassFloatingFallback = DSSurfaceSpec(
        fills: [.solid(T.glassFallback)],
        stroke: .solid(.white),
        shadows: [T.shadowCard, T.shadowCardContact]
    )

    /// 모달 판
    public static let glassModal = DSSurfaceSpec(
        fills: [.solid(T.glassFallback)],
        stroke: T.glassStroke,
        strokeWidth: T.glassStrokeWidthSmall,
        shadows: [T.shadowCard, T.shadowCardContact, T.innerEdge],
        blursBackground: true
    )

    /// 선택된 카드 — 파란 테두리 2pt
    public static let glassCardSelected = DSSurfaceSpec(
        fills: T.glassFill + [T.glassSheenFill],
        stroke: .solid(DSColor.Primary._500),
        strokeWidth: 2,
        shadows: [T.shadowCard, T.shadowCardContact, T.innerEdge, T.innerGlow(14), T.innerShade]
    )

    /// 경고 카드(살구) — 타이머 만료
    public static let cautionCard = DSSurfaceSpec(
        fills: [.solid(DSColor.Caution._50), T.tintedHighlight],
        stroke: .solid(DSColor.Caution._300),
        shadows: [T.shadowCard, T.shadowCardContact, T.innerEdge, T.innerGlow(14), T.innerShade]
    )

    /// 완료 목록 카드(초록)
    public static let successListCard = DSSurfaceSpec(
        fills: [.solid(DSColor.Success._50), T.tintedHighlight],
        stroke: .solid(DSColor.Success._300),
        shadows: [T.shadowList, T.shadowListContact, T.innerEdge, T.innerGlow(12)]
    )

    /// 사진 위 작은 유리 — `GlassIconButton`
    public static let glassSmall = DSSurfaceSpec(
        fills: [
            .solid(T.glassStrokeClear),
            .radial([(T.glassSheen, 0), (UIColor.white.withAlphaComponent(0), 1)], center: CGPoint(x: 0.3, y: 0.2), radius: 0.7)
        ],
        stroke: .linear([(.white, 0), (T.glassStrokeClear, 0.5), (T.glassHighlight, 1)], angle: 135),
        shadows: [T.shadowSmall, DSShadow(color: T.glassHighlight, y: 1, blur: 1, isInner: true)]
    )

    /// 파랗게 물든 유리 — 띄운 버튼
    public static let glassTintPrimary = DSSurfaceSpec(
        fills: [.linear([(T.glassTintPrimaryTop, 0), (T.glassTintPrimaryBottom, 1)], angle: 180)],
        stroke: T.glassStroke,
        strokeWidth: T.glassStrokeWidthSmall,
        shadows: [
            DSShadow(color: T.raisedPrimary.shadow, y: 8, blur: 20),
            DSShadow(color: T.raisedHighlight, y: 1, blur: 1, isInner: true)
        ],
        blursBackground: true
    )

    // MARK: 볼록

    /// 흰 볼록 — 보조 버튼 · 아이콘 버튼 · 드롭다운 칩
    public static func raisedNeutral(stroke: UIColor = DSColor.Neutral._200, strokeWidth: CGFloat = 1) -> DSSurfaceSpec {
        DSSurfaceSpec(
            fills: [.linear([(DSColor.surface, 0), (T.raisedNeutralBottom, 1)], angle: 180)],
            stroke: .solid(stroke),
            strokeWidth: strokeWidth,
            shadows: [T.shadowListContact, T.raisedTopEdge]
        )
    }

    public static let raisedPrimary = raised(T.raisedPrimary)
    public static let raisedCaution = raised(T.raisedCaution)
    public static let raisedError = raised(T.raisedError)

    private static func raised(_ tone: (top: UIColor, bottom: UIColor, shadow: UIColor)) -> DSSurfaceSpec {
        DSSurfaceSpec(
            fills: [.linear([(tone.top, 0), (tone.bottom, 1)], angle: 180)],
            shadows: [DSShadow(color: tone.shadow, y: 1, blur: 2), T.raisedTopHighlight]
        )
    }

    // MARK: 평면

    public static func flat(_ color: UIColor, stroke: UIColor? = nil, strokeWidth: CGFloat = 1) -> DSSurfaceSpec {
        DSSurfaceSpec(fills: [.solid(color)], stroke: stroke.map { .solid($0) }, strokeWidth: strokeWidth)
    }
}

// MARK: - Surface View
// spec대로 면을 그리는 배경 뷰. 내용은 이 뷰 위(형제 또는 자식)에 올린다.
//
// 바깥 그림자는 면 바깥으로만 드리운다(디자인 도구처럼 반투명 면 아래로 비치지 않게 마스크).
// 안쪽 그림자는 면 둘레 바깥에 고리를 그리고 그 그림자만 면 안으로 들어오게 한다.

public final class DSSurfaceView: UIView {

    public var spec: DSSurfaceSpec {
        didSet { rebuild() }
    }

    /// nil이면 높이의 절반(캡슐).
    public var cornerRadius: CGFloat? {
        didSet { setNeedsLayout() }
    }

    private let outerShadowContainer = CALayer()
    private var outerShadowLayers: [CALayer] = []
    private var blurView: UIVisualEffectView?
    private let clipView = UIView()
    private var fillLayers: [CALayer] = []
    private var innerShadowLayers: [CAShapeLayer] = []
    private let strokeLayer = CAGradientLayer()
    private let strokeMask = CAShapeLayer()

    public init(spec: DSSurfaceSpec, cornerRadius: CGFloat? = DSRadius.card) {
        self.spec = spec
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear

        layer.addSublayer(outerShadowContainer)
        clipView.clipsToBounds = true
        clipView.isUserInteractionEnabled = false
        addSubview(clipView)
        strokeMask.fillColor = nil
        strokeMask.strokeColor = UIColor.black.cgColor
        strokeLayer.mask = strokeMask

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceTransparencyChanged),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
        rebuild()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 실제로 그리는 spec — 흐림이 필요한데 '투명도 줄이기'가 켜져 있으면 대체 면.
    private var resolvedSpec: DSSurfaceSpec {
        spec.blursBackground && UIAccessibility.isReduceTransparencyEnabled ? .glassFloatingFallback : spec
    }

    @objc private func reduceTransparencyChanged() {
        rebuild()
    }

    // MARK: - Build

    private func rebuild() {
        let spec = resolvedSpec

        outerShadowLayers.forEach { $0.removeFromSuperlayer() }
        outerShadowLayers = spec.shadows.filter { !$0.isInner }.map { shadow in
            let shadowLayer = CALayer()
            shadowLayer.shadowColor = shadow.color.cgColor
            shadowLayer.shadowOpacity = 1
            shadowLayer.shadowOffset = shadow.offset
            shadowLayer.shadowRadius = shadow.blur / 2
            outerShadowContainer.addSublayer(shadowLayer)
            return shadowLayer
        }

        blurView?.removeFromSuperview()
        blurView = nil
        if spec.blursBackground {
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
            blur.isUserInteractionEnabled = false
            clipView.addSubview(blur)
            blurView = blur
        }

        fillLayers.forEach { $0.removeFromSuperlayer() }
        fillLayers = spec.fills.map(Self.makeLayer)
        fillLayers.forEach { clipView.layer.addSublayer($0) }

        innerShadowLayers.forEach { $0.removeFromSuperlayer() }
        innerShadowLayers = spec.shadows.filter(\.isInner).map { shadow in
            let ring = CAShapeLayer()
            ring.fillRule = .evenOdd
            ring.fillColor = UIColor.black.cgColor
            ring.shadowColor = shadow.color.cgColor
            ring.shadowOpacity = 1
            ring.shadowOffset = shadow.offset
            ring.shadowRadius = shadow.blur / 2
            clipView.layer.addSublayer(ring)
            return ring
        }

        strokeLayer.removeFromSuperlayer()
        if let stroke = spec.stroke {
            Self.apply(stroke, to: strokeLayer)
            strokeMask.lineWidth = spec.strokeWidth
            layer.insertSublayer(strokeLayer, above: clipView.layer)
        }

        setNeedsLayout()
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()

        let radius = min(cornerRadius ?? bounds.height / 2, bounds.height / 2)
        let shape = UIBezierPath(roundedRect: bounds, cornerRadius: radius)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // 바깥 그림자 — 면 바깥만 남기는 마스크
        outerShadowContainer.frame = bounds
        let outside = UIBezierPath(rect: bounds.insetBy(dx: -80, dy: -80))
        outside.append(shape)
        let outsideMask = CAShapeLayer()
        outsideMask.fillRule = .evenOdd
        outsideMask.path = outside.cgPath
        outerShadowContainer.mask = outsideMask
        for shadowLayer in outerShadowLayers {
            shadowLayer.frame = bounds
            shadowLayer.shadowPath = shape.cgPath
        }

        clipView.frame = bounds
        clipView.layer.cornerRadius = radius
        clipView.layer.cornerCurve = .continuous
        blurView?.frame = bounds
        fillLayers.forEach { $0.frame = bounds }

        let ring = UIBezierPath(rect: bounds.insetBy(dx: -40, dy: -40))
        ring.append(shape)
        for ringLayer in innerShadowLayers {
            ringLayer.frame = bounds
            ringLayer.path = ring.cgPath
        }

        // 안쪽 정렬 테두리 — 선 굵기의 절반만큼 들여 그린다
        let inset = strokeMask.lineWidth / 2
        strokeLayer.frame = bounds
        strokeMask.path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: inset, dy: inset),
            cornerRadius: max(radius - inset, 0)
        ).cgPath

        CATransaction.commit()
    }

    // MARK: - Paint

    private static func makeLayer(_ paint: DSSurfaceSpec.Paint) -> CALayer {
        switch paint {
        case .solid(let color):
            let solid = CALayer()
            solid.backgroundColor = color.cgColor
            return solid
        case .linear, .radial:
            let gradient = CAGradientLayer()
            apply(paint, to: gradient)
            return gradient
        }
    }

    private static func apply(_ paint: DSSurfaceSpec.Paint, to gradient: CAGradientLayer) {
        switch paint {
        case .solid(let color):
            gradient.type = .axial
            gradient.colors = [color.cgColor, color.cgColor]
            gradient.locations = nil
        case let .linear(stops, angle):
            // 디자인 각도 → 단위 정사각형 위 방향 벡터 (0 = 아래→위, 시계 방향)
            let radians = angle * .pi / 180
            let dx = sin(radians) / 2
            let dy = -cos(radians) / 2
            gradient.type = .axial
            gradient.colors = stops.map { $0.0.cgColor }
            gradient.locations = stops.map { NSNumber(value: Double($0.1)) }
            gradient.startPoint = CGPoint(x: 0.5 - dx, y: 0.5 - dy)
            gradient.endPoint = CGPoint(x: 0.5 + dx, y: 0.5 + dy)
        case let .radial(stops, center, radius):
            gradient.type = .radial
            gradient.colors = stops.map { $0.0.cgColor }
            gradient.locations = stops.map { NSNumber(value: Double($0.1)) }
            gradient.startPoint = center
            gradient.endPoint = CGPoint(x: center.x + radius / 2, y: center.y + radius / 2)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DSSurfaceView") {
    let container = UIView()
    container.backgroundColor = DSColor.bgApp

    let specs: [(DSSurfaceSpec, CGFloat?)] = [
        (.glassCard, DSRadius.card),
        (.glassListCard, DSRadius.card),
        (.glassFloating, nil),
        (.glassCardSelected, DSRadius.card),
        (.cautionCard, DSRadius.card),
        (.successListCard, DSRadius.card),
        (.raisedPrimary, DSRadius.md),
        (.raisedNeutral(), DSRadius.md)
    ]
    let stack = UIStackView(arrangedSubviews: specs.map { spec, radius in
        let surface = DSSurfaceView(spec: spec, cornerRadius: radius)
        surface.heightAnchor.constraint(equalToConstant: 64).isActive = true
        return surface
    })
    stack.axis = .vertical
    stack.spacing = 20
    stack.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(stack)
    NSLayoutConstraint.activate([
        stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
        stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24)
    ])
    return container
}
#endif
