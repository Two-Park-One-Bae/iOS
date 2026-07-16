import UIKit
import SnapKit
import DSKit
import Core

// 울림 방식 선택기 (소리 / 진동 / 무음) — 3등분 세그먼트. 첫 시작 시트·설정에서 공용.
public final class RingModeSelectorView: UIView {

    public var onChange: ((RingMode) -> Void)?

    private var selected: RingMode
    private var options: [RingMode: OptionView] = [:]

    public init(selected: RingMode = RingModeStore.shared.current) {
        self.selected = selected
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
            let option = OptionView(mode: mode)
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

        init(mode: RingMode) {
            super.init(frame: .zero)
            layer.cornerRadius = 12
            icon.contentMode = .scaleAspectFit
            icon.image = UIImage(systemName: mode.iconName)
            icon.preferredSymbolConfiguration = .init(pointSize: 20, weight: .regular)
            label.text = mode.title
            label.font = DSKitFontFamily.Pretendard.semiBold.font(size: 13)

            let stack = UIStackView(arrangedSubviews: [icon, label])
            stack.axis = .vertical
            stack.spacing = 6
            stack.alignment = .center
            stack.isUserInteractionEnabled = false
            addSubview(stack)
            icon.snp.makeConstraints { $0.height.equalTo(22) }
            stack.snp.makeConstraints {
                $0.top.bottom.equalToSuperview().inset(14)
                $0.leading.trailing.equalToSuperview().inset(8)
            }
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        }

        required init?(coder: NSCoder) { fatalError() }

        @objc private func tapped() { onTap?() }

        func setSelected(_ selected: Bool) {
            backgroundColor = selected ? DSColor.Primary._50 : DSColor.Neutral._50
            layer.borderWidth = selected ? 1.5 : 1
            layer.borderColor = (selected ? DSColor.Primary._500 : DSColor.Neutral._200).cgColor
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
    var iconName: String {
        switch self {
        case .sound:  return "speaker.wave.2.fill"
        case .silent: return "speaker.slash.fill"
        }
    }
}
