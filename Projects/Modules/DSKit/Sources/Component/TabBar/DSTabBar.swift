import UIKit

// MARK: - Tab Bar
// V2.1.0 떠 있는 유리 탭 바(`Jnwka`): 높이 62, 캡슐, 면 glassFloating, padding 5. 항목은 같은 폭으로 나눈다.
// 선택:   흰 판(glass-inner-glow) + 흰 테두리 1px, 아이콘 24 Primary500, Label SemiBold 10 Primary600
// 미선택: 아이콘 24 textTertiary, Label Regular 10 textTertiary
// 탭 전환 자체는 UITabBarController 가 맡고, 이 뷰는 그리기와 누름만 한다.
//
// 움직임 — iOS 26 시스템 유리 탭 바를 흉내 낸다.
// - 누르는 순간 선택 판이 누른 탭으로 달려가며 납작하게 퍼졌다 부푼다(물방울이 눌리는 것처럼).
// - 누른 채 끌면 판이 손가락을 따라오고, 빠를수록 가로로 늘고 세로로 납작해진다.
// - 떼면 가장 가까운 탭에 내려앉으며 눌렸다 펴지고 몇 번 출렁인다. 판 아래 아이콘은 살짝 커진다.
// - 코드로 탭을 바꿔도(홈 버튼 · 딥링크) 판이 늘어나며 미끄러진다.
// - '동작 줄이기'가 켜져 있으면 판을 옮기기만 한다.

public final class DSTabBar: UIView {

    public struct Item {
        public let title: String
        public let icon: DSIcon

        public init(title: String, icon: DSIcon) {
            self.title = title
            self.icon = icon
        }
    }

    public static let height: CGFloat = 62

    /// 사용자가 항목을 골랐을 때. 선택 표시는 `selectedIndex`를 바꿔야 확정된다.
    public var onSelect: ((Int) -> Void)?

    public var selectedIndex: Int = 0 {
        didSet {
            guard selectedIndex != oldValue else { return }
            updateItems(animated: window != nil)
            // 손가락으로 끄는 중이면 판은 손가락이 맡는다.
            guard !isTracking else { return }
            movePlate(to: selectedIndex, animated: window != nil)
        }
    }

    private let surface = DSSurfaceView(spec: .glassFloating, cornerRadius: nil)
    private let plate = UIView()
    private let stack = UIStackView()
    private var itemViews: [DSTabBarItemView] = []

    private var isTracking = false
    private var isAnimatingPlate = false
    /// 손가락을 따라갈 때 속도로 늘림을 정한다.
    private var lastTouch: (x: CGFloat, time: TimeInterval)?

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    public init(items: [Item]) {
        super.init(frame: .zero)
        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(surface)

        plate.backgroundColor = DSMaterialToken.glassInnerGlow
        plate.layer.borderColor = UIColor.white.cgColor
        plate.layer.borderWidth = 1
        plate.layer.shadowColor = UIColor.black.cgColor
        plate.layer.shadowOpacity = 0
        plate.layer.shadowRadius = 10
        plate.layer.shadowOffset = CGSize(width: 0, height: 4)
        plate.isUserInteractionEnabled = false
        addSubview(plate)

        itemViews = items.enumerated().map { index, item in
            let view = DSTabBarItemView(item: item)
            view.onAccessibilityActivate = { [weak self] in self?.onSelect?(index) }
            return view
        }
        itemViews.forEach(stack.addArrangedSubview)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5)
        ])
        updateItems(animated: false)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard !isTracking, !isAnimatingPlate else { return }
        let frame = plateFrame(for: selectedIndex)
        plate.transform = .identity
        plate.bounds = CGRect(origin: .zero, size: frame.size)
        plate.center = CGPoint(x: frame.midX, y: frame.midY)
        plate.layer.cornerRadius = frame.height / 2
    }

    // MARK: - Touch

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let x = touches.first?.location(in: self).x else { return }
        isTracking = true
        lastTouch = (x, CACurrentMediaTime())
        // 누르는 순간 판이 누른 자리로 달려가며 납작하게 퍼졌다가 부풀어 자리 잡는다 — 물방울이 눌리는 것처럼.
        animateSpring(duration: 0.35, damping: 0.7) {
            self.plate.center.x = self.clampedPlateX(x)
            self.plate.layer.shadowOpacity = self.reduceMotion ? 0 : 0.12
        }
        if !reduceMotion {
            wobble(duration: 0.38, scales: [(1.24, 0.86), (1.06, 1.18), (1.15, 1.08), (1.12, 1.12)])
        }
        highlightItem(under: x)
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isTracking, let x = touches.first?.location(in: self).x else { return }
        let now = CACurrentMediaTime()
        var velocity: CGFloat = 0
        if let last = lastTouch, now > last.time {
            velocity = (x - last.x) / CGFloat(now - last.time)
        }
        lastTouch = (x, now)

        // 빠를수록 가로로 늘고 세로로 납작해진다 — 물방울처럼.
        let stretch = reduceMotion ? 0 : min(abs(velocity) / 2400, 0.35)
        animateSpring(duration: 0.25, damping: 0.85) {
            self.plate.center.x = self.clampedPlateX(x)
            self.plate.transform = self.reduceMotion
                ? .identity
                : CGAffineTransform(scaleX: 1.12 + stretch, y: 1.12 - stretch * 0.45)
        }
        highlightItem(under: x)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isTracking else { return }
        let x = touches.first?.location(in: self).x ?? plate.center.x
        finishTracking(select: nearestIndex(to: x))
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isTracking else { return }
        finishTracking(select: nil)
    }

    private func finishTracking(select index: Int?) {
        lastTouch = nil
        highlightItem(under: nil)
        // 고르는 동안은 아직 끄는 중으로 둔다 — selectedIndex 가 바뀌어도 판을 두 번 옮기지 않게.
        if let index {
            if index != selectedIndex { UISelectionFeedbackGenerator().selectionChanged() }
            // 이미 고른 탭을 다시 누르면 처음 화면으로 돌아가는 건 받는 쪽이 정한다.
            onSelect?(index)
        }
        isTracking = false
        movePlate(to: selectedIndex, animated: true, landing: true)
    }

    // MARK: - Plate

    private func plateFrame(for index: Int) -> CGRect {
        guard itemViews.indices.contains(index) else { return .zero }
        stack.layoutIfNeeded()
        return stack.convert(itemViews[index].frame, to: self)
    }

    /// 판이 바깥으로 넘치지 않게 첫 · 마지막 탭 중심 사이로 묶는다.
    private func clampedPlateX(_ x: CGFloat) -> CGFloat {
        guard let first = itemViews.first, let last = itemViews.last else { return x }
        let minX = stack.convert(first.frame, to: self).midX
        let maxX = stack.convert(last.frame, to: self).midX
        return min(max(x, minX), maxX)
    }

    private func nearestIndex(to x: CGFloat) -> Int {
        let centers = itemViews.map { stack.convert($0.frame, to: self).midX }
        return centers.enumerated().min { abs($0.element - x) < abs($1.element - x) }?.offset ?? selectedIndex
    }

    /// - landing: 손을 뗀 뒤 — 부푼 판이 줄어들며 튕긴다.
    private func movePlate(to index: Int, animated: Bool, landing: Bool = false) {
        let target = plateFrame(for: index)
        guard animated, bounds.width > 0 else {
            setNeedsLayout()
            return
        }
        if reduceMotion {
            UIView.animate(withDuration: 0.2) {
                self.plate.transform = .identity
                self.plate.layer.shadowOpacity = 0
                self.plate.center = CGPoint(x: target.midX, y: target.midY)
            }
            return
        }

        isAnimatingPlate = true
        // 이동 거리만큼 가로로 늘어난 채 미끄러지고, 도착하면 눌렸다 펴지며 출렁인다.
        let distance = abs(target.midX - plate.center.x)
        let stretch = min(distance / max(target.width, 1), 2) * 0.16
        if !landing && distance > 1 {
            animateSpring(duration: 0.16, damping: 1) {
                self.plate.transform = CGAffineTransform(scaleX: 1 + stretch, y: 1 - stretch * 0.45)
            }
        }
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.72,
            initialSpringVelocity: 0.9,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.plate.center = CGPoint(x: target.midX, y: target.midY)
            self.plate.layer.shadowOpacity = 0
        } completion: { _ in
            self.isAnimatingPlate = false
            self.setNeedsLayout()
        }
        wobble(
            duration: 0.62,
            delay: landing ? 0 : 0.14,
            scales: [(0.9, 1.1), (1.08, 0.93), (0.97, 1.04), (1.02, 0.99), (1, 1)]
        )
    }

    /// 판 모양을 차례로 바꾼다(가로, 세로 배율) — 눌렸다 펴지는 물방울 출렁임.
    private func wobble(duration: TimeInterval, delay: TimeInterval = 0, scales: [(CGFloat, CGFloat)]) {
        let step = 1.0 / Double(scales.count)
        UIView.animateKeyframes(
            withDuration: duration,
            delay: delay,
            options: [.calculationModeCubic, .allowUserInteraction, .beginFromCurrentState]
        ) {
            for (index, scale) in scales.enumerated() {
                UIView.addKeyframe(withRelativeStartTime: Double(index) * step, relativeDuration: step) {
                    self.plate.transform = CGAffineTransform(scaleX: scale.0, y: scale.1)
                }
            }
        }
    }

    private func animateSpring(duration: TimeInterval, damping: CGFloat, _ changes: @escaping () -> Void) {
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: damping,
            initialSpringVelocity: 0.8,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: changes
        )
    }

    // MARK: - Items

    private func updateItems(animated: Bool) {
        for (index, view) in itemViews.enumerated() {
            view.setSelected(index == selectedIndex, animated: animated)
        }
    }

    /// 판 아래 아이콘을 살짝 키운다. nil이면 모두 원래대로.
    private func highlightItem(under x: CGFloat?) {
        let index = x.map(nearestIndex(to:))
        for (i, view) in itemViews.enumerated() {
            view.setMagnified(i == index && !reduceMotion)
        }
    }
}

// MARK: - Item

private final class DSTabBarItemView: UIView {

    var onAccessibilityActivate: (() -> Void)?

    private let iconView = UIImageView()
    private let label = UILabel()
    private let content = UIStackView()
    private(set) var isSelected = false
    private var isMagnified = false

    init(item: DSTabBar.Item) {
        super.init(frame: .zero)
        iconView.image = item.icon.uiImage
        iconView.contentMode = .scaleAspectFit
        label.text = item.title
        label.textAlignment = .center

        [iconView, label].forEach(content.addArrangedSubview)
        content.axis = .vertical
        content.spacing = 2
        content.alignment = .center
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            content.centerXAnchor.constraint(equalTo: centerXAnchor),
            content.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        isAccessibilityElement = true
        accessibilityLabel = item.title
        apply()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func accessibilityActivate() -> Bool {
        onAccessibilityActivate?()
        return true
    }

    func setSelected(_ selected: Bool, animated: Bool) {
        guard selected != isSelected else { return }
        isSelected = selected
        guard animated else {
            apply()
            return
        }
        UIView.transition(with: content, duration: 0.25, options: [.transitionCrossDissolve, .allowUserInteraction]) {
            self.apply()
        }
    }

    func setMagnified(_ magnified: Bool) {
        guard magnified != isMagnified else { return }
        isMagnified = magnified
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0.8,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.content.transform = magnified ? CGAffineTransform(scaleX: 1.12, y: 1.12) : .identity
        }
    }

    private func apply() {
        iconView.tintColor = isSelected ? DSColor.Primary._500 : DSColor.textTertiary
        label.textColor = isSelected ? DSColor.Primary._600 : DSColor.textTertiary
        label.font = isSelected
            ? DSKitFontFamily.Pretendard.semiBold.font(size: 10)
            : DSKitFontFamily.Pretendard.regular.font(size: 10)
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DSTabBar") {
    let container = UIView()
    container.backgroundColor = .white
    let bar = DSTabBar(items: [
        .init(title: "홈", icon: .house),
        .init(title: "알약", icon: .pill),
        .init(title: "타이머", icon: .timer),
        .init(title: "설정", icon: .settings)
    ])
    // 프리뷰에서도 눌러서 · 끌어서 움직임을 볼 수 있게 선택을 바로 반영한다.
    bar.onSelect = { [weak bar] index in bar?.selectedIndex = index }
    bar.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(bar)
    NSLayoutConstraint.activate([
        bar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
        bar.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
        bar.centerYAnchor.constraint(equalTo: container.centerYAnchor)
    ])
    return container
}
#endif
