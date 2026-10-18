import UIKit
import SnapKit
import Then
import DSKit
import Domain

// C3 프리셋 시트 (W2Xi4t / 편집 모드 lbWur) — 프리셋 원탭 = 즉시 시작
// V2.1.0(NM-591): 행 · 프리셋 추가는 흰 볼록(r12). 편집 모드에서 ≡ 를 끌어 순서를 바꾼다(저장 순서 = 노출 순서).
final class PresetSheetVC: UIViewController {

    // MARK: - Callbacks

    var onSelectPreset: ((TimerPresetModel) -> Void)?
    var onAddPreset: (() -> Void)?
    var onEditPreset: ((TimerPresetModel) -> Void)?
    var onDeletePreset: ((TimerPresetModel) -> Void)?
    /// 편집 모드 드래그 정렬 — 프리셋과 놓은 자리(0부터).
    var onMovePreset: ((TimerPresetModel, Int) -> Void)?

    // MARK: - Properties

    private var presets: [TimerPresetModel] = []
    private var isEditMode = false

    // 드래그 정렬 상태
    private var draggingRow: PresetRaisedRow?
    private var dragTouchOffset: CGFloat = 0
    private var dragStartIndex = 0
    private let selectionFeedback = UISelectionFeedbackGenerator()

    // MARK: - UI

    private let subLabel = UILabel().then {
        $0.text = "누르면 타이머가 바로 시작됩니다"
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
        $0.textColor = DSColor.textSecondary
    }
    private let editButton = UIButton(type: .system).then {
        $0.setTitle("편집", for: .normal)
        $0.setTitleColor(DSColor.Primary._600, for: .normal)
        $0.titleLabel?.font = DSKitFontFamily.Pretendard.medium.font(size: 14)
    }
    private let scrollView = UIScrollView().then {
        $0.showsVerticalScrollIndicator = false
    }
    private let listStack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 8
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setLayout()
        renderList()
    }

    // MARK: - Public

    func updatePresets(_ presets: [TimerPresetModel]) {
        self.presets = presets
        guard isViewLoaded else { return }
        renderList()
    }

    // MARK: - Layout

    private func setLayout() {
        view.backgroundColor = DSColor.surface

        let title = UILabel().then {
            $0.text = "프리셋"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 18)
            $0.textColor = DSColor.textPrimary
        }
        let titleRow = UIStackView(arrangedSubviews: [title, UIView(), editButton]).then {
            $0.axis = .horizontal; $0.alignment = .center
        }
        let header = UIStackView(arrangedSubviews: [titleRow, subLabel]).then {
            $0.axis = .vertical; $0.spacing = 4; $0.alignment = .fill
        }

        view.addSubview(header)
        header.snp.makeConstraints {
            $0.top.equalToSuperview().offset(24)
            $0.leading.trailing.equalToSuperview().inset(20)
        }

        view.addSubview(scrollView)
        scrollView.addSubview(listStack)
        scrollView.snp.makeConstraints {
            $0.top.equalTo(header.snp.bottom).offset(14)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(20)
        }
        listStack.snp.makeConstraints {
            $0.edges.equalTo(scrollView.contentLayoutGuide).inset(UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20))
            $0.width.equalTo(scrollView.frameLayoutGuide).offset(-40)
        }

        editButton.addAction(UIAction { [weak self] _ in self?.toggleEditMode() }, for: .touchUpInside)
    }

    private func toggleEditMode() {
        isEditMode.toggle()
        editButton.setTitle(isEditMode ? "완료" : "편집", for: .normal)
        editButton.titleLabel?.font = isEditMode
            ? DSKitFontFamily.Pretendard.semiBold.font(size: 14)
            : DSKitFontFamily.Pretendard.medium.font(size: 14)
        subLabel.text = isEditMode ? "프리셋을 눌러 수정 · ≡ 드래그로 순서 변경" : "누르면 타이머가 바로 시작됩니다"
        renderList()
    }

    // MARK: - Render

    private func renderList() {
        // 끄는 중에는 다시 그리지 않는다 — 놓은 뒤 저장되며 새 목록이 온다.
        guard draggingRow == nil else { return }
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for preset in presets {
            listStack.addArrangedSubview(makeRow(preset))
        }
        listStack.addArrangedSubview(makeAddRow())
    }

    private func makeRow(_ preset: TimerPresetModel) -> UIView {
        let row = PresetRaisedRow()
        row.presetID = preset.id

        let label = UILabel().then {
            $0.text = preset.label
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 15)
            $0.textColor = DSColor.textPrimary
        }
        let tag = UIView().then {
            $0.backgroundColor = preset.category.tagBackground
            $0.layer.cornerRadius = 6
        }
        let tagLabel = UILabel().then {
            $0.text = preset.category.displayName
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 11)
            $0.textColor = preset.category.tagText
        }
        tag.addSubview(tagLabel)
        tagLabel.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(3)
            $0.leading.trailing.equalToSuperview().inset(8)
        }
        let duration = UILabel().then {
            $0.text = TimerFormat.duration(preset.duration)
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 13)
            $0.textColor = DSColor.textSecondary
        }

        var leading: [UIView] = []
        var trailing: UIView

        if isEditMode {
            // 삭제(빨간 휴지통) + … + chevron (행 탭 = 편집)
            let minus = UIButton(type: .system).then {
                $0.setImage(DSIcon.trash.uiImage(size: 20), for: .normal)
                $0.tintColor = DSColor.Error._500
                $0.accessibilityLabel = "\(preset.label) 삭제"
            }
            minus.snp.makeConstraints { $0.width.height.equalTo(24) }
            minus.addAction(UIAction { [weak self] _ in self?.onDeletePreset?(preset) }, for: .touchUpInside)
            leading = [minus]

            // 드래그 핸들 — 끌기는 핸들 둘레(44)에서 시작해야 받는다(gestureRecognizerShouldBegin).
            let handle = UIView()
            let handleIcon = UIImageView(image: DSIcon.menu.uiImage).then {
                $0.tintColor = DSColor.Neutral._400
                $0.contentMode = .scaleAspectFit
            }
            handle.addSubview(handleIcon)
            handleIcon.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(18) }
            handle.snp.makeConstraints { $0.width.equalTo(18); $0.height.equalTo(24) }
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDrag(_:)))
            pan.delegate = self
            row.addGestureRecognizer(pan)
            row.dragHandle = handle
            scrollView.panGestureRecognizer.require(toFail: pan)
            trailing = handle

            row.isAccessibilityElement = true
            row.accessibilityLabel = "\(preset.label), \(TimerFormat.duration(preset.duration))"
            row.accessibilityTraits = .button
            row.accessibilityCustomActions = [
                UIAccessibilityCustomAction(name: "위로 이동") { [weak self] _ in self?.moveByStep(preset, -1) ?? false },
                UIAccessibilityCustomAction(name: "아래로 이동") { [weak self] _ in self?.moveByStep(preset, 1) ?? false },
                UIAccessibilityCustomAction(name: "삭제") { [weak self] _ in self?.onDeletePreset?(preset); return true }
            ]

            row.addAction(UIAction { [weak self] _ in self?.onEditPreset?(preset) }, for: .touchUpInside)
        } else {
            let play = UIImageView().then {
                $0.image = DSIcon.circlePlay.uiImage
                $0.tintColor = DSColor.Primary._500
                $0.contentMode = .scaleAspectFit
            }
            play.snp.makeConstraints { $0.width.height.equalTo(28) }
            trailing = play

            row.addAction(UIAction { [weak self] _ in self?.onSelectPreset?(preset) }, for: .touchUpInside)
        }

        let stack = UIStackView(arrangedSubviews: leading + [label, tag, UIView(), duration, trailing]).then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.alignment = .center
            $0.isUserInteractionEnabled = false
        }
        // 삭제 버튼은 탭 가능해야 함
        leading.forEach { $0.isUserInteractionEnabled = true }
        stack.setCustomSpacing(10, after: duration)

        row.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(12)
            $0.leading.trailing.equalToSuperview().inset(14)
        }
        if isEditMode {
            stack.isUserInteractionEnabled = true
            label.isUserInteractionEnabled = false
        }
        return row
    }

    private func makeAddRow() -> UIView {
        let row = PresetRaisedRow()
        let plus = UIImageView(image: DSIcon.plus.uiImage).then {
            $0.tintColor = DSColor.Primary._700
            $0.contentMode = .scaleAspectFit
        }
        plus.snp.makeConstraints { $0.width.height.equalTo(18) }
        let label = UILabel().then {
            $0.text = "프리셋 추가"
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 14)
            $0.textColor = DSColor.Primary._700
        }
        let stack = UIStackView(arrangedSubviews: [plus, label]).then {
            $0.axis = .horizontal; $0.spacing = 6; $0.alignment = .center
            $0.isUserInteractionEnabled = false
        }
        row.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(12)
            $0.centerX.equalToSuperview()
        }
        row.addAction(UIAction { [weak self] _ in self?.onAddPreset?() }, for: .touchUpInside)
        return row
    }
}

// MARK: - 드래그 정렬

extension PresetSheetVC: UIGestureRecognizerDelegate {

    // ≡ 핸들에서 시작한 끌기만 받는다 — 행의 나머지는 탭(편집)이다.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let row = gestureRecognizer.view as? PresetRaisedRow, let handle = row.dragHandle else { return false }
        let point = gestureRecognizer.location(in: handle)
        return handle.bounds.insetBy(dx: -14, dy: -10).contains(point)
    }

    private var presetRows: [PresetRaisedRow] {
        listStack.arrangedSubviews.compactMap { $0 as? PresetRaisedRow }.filter { $0.presetID != nil }
    }

    @objc fileprivate func handleDrag(_ pan: UIPanGestureRecognizer) {
        guard let row = pan.view as? PresetRaisedRow else { return }
        let y = pan.location(in: listStack).y
        switch pan.state {
        case .began:
            draggingRow = row
            dragStartIndex = presetRows.firstIndex(of: row) ?? 0
            dragTouchOffset = y - row.center.y
            isModalInPresentation = true // 끄는 동안 시트가 내려가지 않게
            listStack.bringSubviewToFront(row)
            selectionFeedback.prepare()
            UIView.animate(withDuration: 0.15) { row.setLifted(true) }
        case .changed:
            let targetY = y - dragTouchOffset
            let rows = presetRows
            guard let current = rows.firstIndex(of: row) else { return }
            // 이웃 행의 가운데를 넘으면 자리를 바꾼다.
            var index = current
            while index > 0, targetY < rows[index - 1].center.y { index -= 1 }
            while index < rows.count - 1, targetY > rows[index + 1].center.y { index += 1 }
            if index != current {
                selectionFeedback.selectionChanged()
                UIView.animate(withDuration: 0.2) {
                    self.listStack.insertArrangedSubview(row, at: index)
                    self.listStack.layoutIfNeeded()
                    row.setLifted(true, offset: targetY - row.center.y)
                }
            } else {
                row.setLifted(true, offset: targetY - row.center.y)
            }
        case .ended, .cancelled, .failed:
            let endIndex = presetRows.firstIndex(of: row) ?? dragStartIndex
            UIView.animate(withDuration: 0.2, animations: { row.setLifted(false) }) { _ in
                self.draggingRow = nil
                self.isModalInPresentation = false
                if endIndex != self.dragStartIndex,
                   let id = row.presetID,
                   let preset = self.presets.first(where: { $0.id == id }) {
                    self.onMovePreset?(preset, endIndex)
                }
            }
        default:
            break
        }
    }

    /// VoiceOver 위로 · 아래로 이동.
    fileprivate func moveByStep(_ preset: TimerPresetModel, _ step: Int) -> Bool {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return false }
        let target = index + step
        guard presets.indices.contains(target) else { return false }
        onMovePreset?(preset, target)
        return true
    }
}

// MARK: - 흰 볼록 행

/// 프리셋 행 · 프리셋 추가 — 흰 볼록 면(raisedNeutral, r12).
private final class PresetRaisedRow: UIControl {

    private let surface = DSSurfaceView(spec: .raisedNeutral(), cornerRadius: DSRadius.md)

    /// 프리셋 행이면 그 프리셋(프리셋 추가 행은 nil).
    var presetID: UUID?
    /// 편집 모드 드래그 핸들.
    weak var dragHandle: UIView?

    init() {
        super.init(frame: .zero)
        surface.isUserInteractionEnabled = false
        addSubview(surface)
        surface.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { surface.alpha = isHighlighted ? 0.85 : 1 }
    }

    /// 끄는 행 — 살짝 키우고 그림자를 진하게, 손가락을 따라 세로로 옮긴다.
    func setLifted(_ lifted: Bool, offset: CGFloat = 0) {
        transform = lifted
            ? CGAffineTransform(translationX: 0, y: offset).scaledBy(x: 1.02, y: 1.02)
            : .identity
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = lifted ? 0.12 : 0
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 6)
    }
}
