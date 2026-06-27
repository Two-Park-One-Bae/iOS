import UIKit

// MARK: - Chip
// 배경 Info50, stroke Info100 1px, cornerRadius 20 (pill)
// padding (8, 14), gap 6
// circle ring 14x14 Info500 (outline), Label Medium 13 Info600

public final class DSChip: UIView {

    // MARK: - UI

    private let circleView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 7
        view.layer.borderWidth = 1.5
        view.layer.borderColor = DSColor.Info._500.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 14),
            view.heightAnchor.constraint(equalToConstant: 14)
        ])
        return view
    }()

    private let label: UILabel = {
        let label = UILabel()
        label.font = DSKitFontFamily.Pretendard.medium.font(size: 13)
        label.textColor = DSColor.Info._600
        return label
    }()

    // MARK: - Init

    public init(text: String, showDot: Bool = true) {
        super.init(frame: .zero)
        label.text = text
        circleView.isHidden = !showDot
        setupUI()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = DSColor.Info._50
        layer.cornerRadius = 20
        layer.borderColor = DSColor.Info._100.cgColor
        layer.borderWidth = 1

        let stack = UIStackView(arrangedSubviews: [circleView, label])
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
}

// MARK: - Methods

extension DSChip {

    public func setText(_ text: String) {
        label.text = text
    }

    public func setCircleHidden(_ hidden: Bool) {
        circleView.isHidden = hidden
    }

    public func setCircleColor(_ color: UIColor) {
        circleView.layer.borderColor = color.cgColor
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DSChip") {
    DSChip(text: "라벨")
}
#endif
