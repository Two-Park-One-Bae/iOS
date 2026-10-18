import UIKit
import SnapKit
import DSKit
import Core
import TimerShared

// 울림 방식 선택기 (소리 / 무음) — 등분 세그먼트. 첫 시작 시트·설정에서 공용.
// V2.1.0(NM-592): 설정 카드 안에서는 흰 볼록(raised) — 고르면 파란 테두리. 첫 시작 시트는 납작한 면 그대로.
public final class RingModeSelectorView: UIView {

    public enum Style {
        /// 첫 시작 시트 — Primary50 / Neutral50 면.
        case flat
        /// 설정 카드 — 흰 볼록 면, 고르면 Primary500 테두리 1.5.
        case raised
    }

    public var onChange: ((RingMode) -> Void)?

    private var selected: RingMode
    private let style: Style
    private var options: [RingMode: OptionView] = [:]

    public init(selected: RingMode = RingModeStore.shared.current, style: Style = .flat) {
        self.selected = selected
        self.style = style
        super.init(frame: .zero)
        setup()
    }

    public required init?(coder: NSCoder) { fatalError() }

    public var selectedMode: RingMode { selected }

    private func setup() {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.distribution = .fillEqually
        addSubview(row)
        row.snp.makeConstraints { $0.edges.equalToSuperview() }

        for mode in RingMode.allCases {
            let option = OptionView(mode: mode, style: style)
            option.onTap = { [weak self] in self?.select(mode) }
            options[mode] = option
            row.addArrangedSubview(option)
        }
        updateSelection()
    }

    private func select(_ mode: RingMode) {
        guard mode != selected else { return }
        selected = mode
        updateSelection()
        onChange?(mode)
    }

    private func updateSelection() {
        options.forEach { $0.value.setSelected($0.key == selected) }
    }

    // MARK: - Option

    private final class OptionView: UIView {
        var onTap: (() -> Void)?
        private let icon = UIImageView()
        private let label = UILabel()
        private let style: Style
        private let surface = DSSurfaceView(spec: .raisedNeutral(), cornerRadius: DSRadius.md)

        init(mode: RingMode, style: Style) {
            self.style = style
            super.init(frame: .zero)
            layer.cornerRadius = 12
            if style == .raised {
                surface.isUserInteractionEnabled = false
                addSubview(surface)
                surface.snp.makeConstraints { $0.edges.equalToSuperview() }
            }
            isAccessibilityElement = true
            accessibilityTraits = .button
            accessibilityLabel = mode.title
            icon.contentMode = .scaleAspectFit
            icon.image = mode.icon.uiImage
            label.text = mode.title
            label.font = DSKitFontFamily.Pretendard.semiBold.font(size: 13)

            let stack = UIStackView(arrangedSubviews: [icon, label])
            stack.axis = .vertical
            stack.spacing = 6
            stack.alignment = .center
            stack.isUserInteractionEnabled = false
            addSubview(stack)
            icon.snp.makeConstraints { $0.width.height.equalTo(22) }
            stack.snp.makeConstraints {
                $0.top.bottom.equalToSuperview().inset(14)
                $0.leading.trailing.equalToSuperview().inset(8)
            }
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        }

        required init?(coder: NSCoder) { fatalError() }

        @objc private func tapped() { onTap?() }

        func setSelected(_ selected: Bool) {
            accessibilityTraits = selected ? [.button, .selected] : .button
            switch style {
            case .flat:
                backgroundColor = selected ? DSColor.Primary._50 : DSColor.Neutral._50
                layer.borderWidth = selected ? 1.5 : 1
                layer.borderColor = (selected ? DSColor.Primary._500 : DSColor.Neutral._200).cgColor
            case .raised:
                surface.spec = selected
                    ? .raisedNeutral(stroke: DSColor.Primary._500, strokeWidth: 1.5)
                    : .raisedNeutral()
            }
            let tint = selected ? DSColor.Primary._600 : DSColor.textSecondary
            icon.tintColor = tint
            label.textColor = selected ? DSColor.Primary._700 : DSColor.textSecondary
        }
    }
}

// MARK: - RingMode display

extension RingMode {
    var title: String {
        switch self {
        case .sound:  return "소리"
        case .silent: return "무음"
        }
    }
    var icon: DSIcon {
        switch self {
        case .sound:  return .volume
        case .silent: return .volumeX
        }
    }
}
