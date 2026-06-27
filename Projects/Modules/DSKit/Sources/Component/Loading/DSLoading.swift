import UIKit

// MARK: - Loading
// Spinner: 40x40 ring(innerRadius 0.78), 280° arc, Info500
// Label: Pretendard Medium 14 textSecondary
// vertical, gap 14, padding 24, center

public final class DSLoading: UIView {

    // MARK: - UI

    private let spinnerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 40),
            view.heightAnchor.constraint(equalToConstant: 40)
        ])
        return view
    }()

    private let spinnerLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        let center = CGPoint(x: 20, y: 20)
        let radius: CGFloat = 20 - 2.2
        let startAngle: CGFloat = -.pi / 2
        let endAngle: CGFloat = startAngle + (280.0 / 360.0) * 2 * .pi
        layer.path = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        ).cgPath
        layer.strokeColor = DSColor.Info._500.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 4.4
        layer.lineCap = .round
        return layer
    }()

    private let label: UILabel = {
        let label = UILabel()
        label.font = DSKitFontFamily.Pretendard.medium.font(size: 14)
        label.textColor = DSColor.textSecondary
        label.textAlignment = .center
        return label
    }()

    // MARK: - Init

    public init(text: String = "로딩 중...") {
        super.init(frame: .zero)
        label.text = text
        setupUI()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        spinnerView.layer.addSublayer(spinnerLayer)

        let stack = UIStackView(arrangedSubviews: [spinnerView, label])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24)
        ])
    }

    // MARK: - Animation

    public func startAnimating() {
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = 2 * Double.pi
        rotation.duration = 1.0
        rotation.repeatCount = .infinity
        spinnerView.layer.add(rotation, forKey: "spin")
    }

    public func stopAnimating() {
        spinnerView.layer.removeAnimation(forKey: "spin")
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startAnimating()
        } else {
            stopAnimating()
        }
    }
}

// MARK: - Methods

extension DSLoading {

    public func setText(_ text: String) {
        label.text = text
    }

    public func setLabelHidden(_ hidden: Bool) {
        label.isHidden = hidden
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DSLoading") {
    DSLoading(text: "식별 중...")
}
#endif
