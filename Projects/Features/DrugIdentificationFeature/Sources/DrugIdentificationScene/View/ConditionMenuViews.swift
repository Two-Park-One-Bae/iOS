import UIKit
import SnapKit
import Then
import DSKit

// ⑧ 수정 화면 조건 메뉴 (DESIGN.pen NM-490 ⑧-b~d · 마크 · 구분선 메뉴)
//
// 격자형 — 색(복수) · 모양 · 제형 · 구분선: 맨 위 `전체` + 값 칸.
// 목록형 — 각인(전체 · 없음 · 입력) · 마크(전체 · 없음 · 있음).
// 고른 칸은 호박색(= 확실한 값), `전체` 는 체크로 표시한다.

// MARK: - 격자형

struct ConditionGridItem {
    let id: String
    let label: String
    let icon: UIView
    /// 고른 칸의 그림 모양 — 색 원은 진한 호박 테두리, 모양 · 제형 그림은 호박색(디자인 ⑧-b~d).
    var applySelected: ((Bool) -> Void)? = nil
}

final class ConditionGridMenuView: UIView {

    /// 칸을 눌렀다(nil = `전체`). 복수 선택이 아니면 누른 뒤 메뉴가 닫힌다.
    var onSelect: ((String?) -> Void)?

    private let items: [ConditionGridItem]
    private let multiple: Bool
    private var selected: Set<String>
    private var cellViews: [String: (box: UIView, label: UILabel, applySelected: ((Bool) -> Void)?)] = [:]
    private let allCheck = UIImageView(image: DSIcon.check.uiImage)
    private let allLabel = UILabel()
    private let allRow = UIControl()

    /// - Parameter modelPreview: `전체` 옆 '사진 기준' 그림 — 모델값이 있을 때만.
    init(items: [ConditionGridItem], selected: Set<String>, multiple: Bool, modelPreview: UIView?) {
        self.items = items
        self.multiple = multiple
        self.selected = selected
        super.init(frame: .zero)
        backgroundColor = DSColor.surface
        layer.cornerRadius = 16
        layer.shadowColor = DSColor.textPrimary.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.shadowRadius = 20
        setup(modelPreview: modelPreview)
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(modelPreview: UIView?) {
        allRow.layer.cornerRadius = 10
        allRow.accessibilityLabel = "전체"
        allRow.addAction(UIAction { [weak self] _ in self?.tap(nil) }, for: .touchUpInside)
        allCheck.tintColor = DSColor.Primary._600
        allCheck.snp.makeConstraints { $0.width.height.equalTo(16) }
        allLabel.text = "전체"
        var rowItems: [UIView] = [allCheck, allLabel, UIView()]
        if let modelPreview {
            let caption = UILabel().then {
                $0.text = "사진 기준"
                $0.font = DSKitFontFamily.Pretendard.regular.font(size: 11)
                $0.textColor = DSColor.textTertiary
            }
            rowItems += [modelPreview, caption]
        }
        let row = UIStackView(arrangedSubviews: rowItems).then {
            $0.axis = .horizontal
            $0.spacing = 10
            $0.alignment = .center
            $0.isUserInteractionEnabled = false
        }
        allRow.addSubview(row)
        allRow.snp.makeConstraints { $0.height.equalTo(44) }
        row.snp.makeConstraints { $0.centerY.equalToSuperview(); $0.leading.trailing.equalToSuperview().inset(12) }

        let divider = UIView().then {
            $0.backgroundColor = DSColor.Neutral._200
            $0.snp.makeConstraints { $0.height.equalTo(1) }
        }
        let stack = UIStackView(arrangedSubviews: [allRow, divider]).then {
            $0.axis = .vertical
            $0.spacing = 6
        }
        for chunk in stride(from: 0, to: items.count, by: 4).map({ Array(items[$0..<min($0 + 4, items.count)]) }) {
            let row = UIStackView().then {
                $0.axis = .horizontal
                $0.spacing = 4
                $0.distribution = .fillEqually
            }
            chunk.forEach { row.addArrangedSubview(makeCell($0)) }
            // 마지막 줄이 4칸이 안 되면 빈칸으로 폭을 맞춘다.
            (chunk.count..<4).forEach { _ in row.addArrangedSubview(UIView()) }
            stack.addArrangedSubview(row)
        }
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(10) }
    }

    private func makeCell(_ item: ConditionGridItem) -> UIView {
        let cell = UIControl().then {
            $0.layer.cornerRadius = 10
            $0.accessibilityLabel = item.label
            $0.addAction(UIAction { [weak self] _ in self?.tap(item.id) }, for: .touchUpInside)
        }
        let label = UILabel().then {
            $0.text = item.label
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 11)
            $0.textAlignment = .center
        }
        let iconBox = UIView()
        iconBox.addSubview(item.icon)
        item.icon.snp.makeConstraints { $0.center.equalToSuperview() }
        iconBox.snp.makeConstraints { $0.height.equalTo(30) }
        let stack = UIStackView(arrangedSubviews: [iconBox, label]).then {
            $0.axis = .vertical
            $0.spacing = 4
            $0.isUserInteractionEnabled = false
        }
        cell.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)) }
        cellViews[item.id] = (cell, label, item.applySelected)
        return cell
    }

    private func tap(_ id: String?) {
        if let id {
            if multiple {
                if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
            } else {
                selected = [id]
            }
        } else {
            selected = []
        }
        refresh()
        onSelect?(id)
    }

    /// 복수 선택에서 지금 고른 값들(순서는 칸 순서).
    var selectedIDs: [String] { items.map(\.id).filter(selected.contains) }

    private func refresh() {
        let isAll = selected.isEmpty
        allCheck.alpha = isAll ? 1 : 0
        allRow.backgroundColor = isAll ? DSColor.Neutral._100 : .clear
        allLabel.font = isAll ? DSKitFontFamily.Pretendard.bold.font(size: 14) : DSKitFontFamily.Pretendard.medium.font(size: 14)
        allLabel.textColor = DSColor.textPrimary
        for (id, views) in cellViews {
            let on = selected.contains(id)
            views.box.backgroundColor = on ? DSColor.Warning._50 : .clear
            views.box.layer.borderWidth = on ? 1 : 0
            views.box.layer.borderColor = DSColor.Warning._300.cgColor
            views.label.textColor = on ? DSColor.Warning._900 : DSColor.textSecondary
            views.label.font = on ? DSKitFontFamily.Pretendard.bold.font(size: 11) : DSKitFontFamily.Pretendard.medium.font(size: 11)
            views.box.accessibilityTraits = on ? [.button, .selected] : .button
            views.applySelected?(on)
        }
    }
}

// MARK: - 목록형

final class ConditionListMenuView: UIView {

    var onSelect: ((Int) -> Void)?

    init(options: [String], selectedIndex: Int) {
        super.init(frame: .zero)
        backgroundColor = DSColor.surface
        layer.cornerRadius = 12
        layer.shadowColor = DSColor.textPrimary.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.shadowRadius = 20
        let stack = UIStackView().then { $0.axis = .vertical }
        for (index, option) in options.enumerated() {
            let on = index == selectedIndex
            let row = UIControl().then {
                $0.layer.cornerRadius = 8
                $0.backgroundColor = on ? DSColor.Neutral._100 : .clear
                $0.accessibilityLabel = option
                $0.accessibilityTraits = on ? [.button, .selected] : .button
                $0.addAction(UIAction { [weak self] _ in self?.onSelect?(index) }, for: .touchUpInside)
            }
            let check = UIImageView(image: DSIcon.check.uiImage).then {
                $0.tintColor = DSColor.Primary._600
                $0.alpha = on ? 1 : 0
                $0.snp.makeConstraints { $0.width.height.equalTo(16) }
            }
            let label = UILabel().then {
                $0.text = option
                $0.font = on ? DSKitFontFamily.Pretendard.bold.font(size: 14) : DSKitFontFamily.Pretendard.medium.font(size: 14)
                $0.textColor = DSColor.textPrimary
            }
            let content = UIStackView(arrangedSubviews: [check, label, UIView()]).then {
                $0.axis = .horizontal
                $0.spacing = 8
                $0.alignment = .center
                $0.isUserInteractionEnabled = false
            }
            row.addSubview(content)
            row.snp.makeConstraints { $0.height.equalTo(40) }
            content.snp.makeConstraints { $0.centerY.equalToSuperview(); $0.leading.trailing.equalToSuperview().inset(10) }
            stack.addArrangedSubview(row)
        }
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(6) }
        snp.makeConstraints { $0.width.equalTo(160) }
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - 띄우기

/// 메뉴를 기준 칸 바로 아래(자리가 없으면 위)에 띄우고, 바깥을 누르면 닫는다.
enum ConditionMenuPresenter {

    /// - Returns: 닫기 함수.
    @discardableResult
    static func present(_ menu: UIView, below anchor: UIView, in host: UIView, fullWidth: Bool,
                        onDismiss: (() -> Void)? = nil) -> () -> Void {
        let scrim = DismissScrim(frame: host.bounds)
        scrim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.addSubview(scrim)
        scrim.addSubview(menu)

        let anchorFrame = anchor.convert(anchor.bounds, to: host)
        let size = menu.systemLayoutSizeFitting(
            CGSize(width: fullWidth ? host.bounds.width - 32 : 160, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel
        )
        let safeBottom = host.bounds.height - host.safeAreaInsets.bottom - 8
        let below = anchorFrame.maxY + 6
        let top = below + size.height <= safeBottom ? below : max(host.safeAreaInsets.top + 8, anchorFrame.minY - 6 - size.height)
        menu.snp.makeConstraints {
            $0.top.equalToSuperview().offset(top)
            if fullWidth {
                $0.leading.trailing.equalToSuperview().inset(16)
            } else {
                let x = min(max(16, anchorFrame.maxX - 160), host.bounds.width - 16 - 160)
                $0.leading.equalToSuperview().offset(x)
            }
        }
        let dismiss = { [weak scrim] in
            guard let scrim, scrim.superview != nil else { return }
            scrim.removeFromSuperview()
            onDismiss?()
        }
        scrim.onDismiss = dismiss
        UIAccessibility.post(notification: .screenChanged, argument: menu)
        return dismiss
    }

    private final class DismissScrim: UIView {
        var onDismiss: (() -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = UIColor.black.withAlphaComponent(0.001)
            accessibilityViewIsModal = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
            tap.cancelsTouchesInView = false
            addGestureRecognizer(tap)
        }

        required init?(coder: NSCoder) { fatalError() }

        @objc private func tapped(_ gesture: UITapGestureRecognizer) {
            // 메뉴 바깥을 눌렀을 때만 닫는다.
            let point = gesture.location(in: self)
            if !subviews.contains(where: { $0.frame.contains(point) }) { onDismiss?() }
        }

        override func accessibilityPerformEscape() -> Bool {
            onDismiss?()
            return true
        }
    }
}
