import UIKit
import SnapKit
import Then
import DSKit
import Domain

// C3 프리셋 시트 (W2Xi4t / 편집 모드 lbWur) — 프리셋 원탭 = 즉시 시작
final class PresetSheetVC: UIViewController {

    // MARK: - Callbacks

    var onSelectPreset: ((TimerPresetModel) -> Void)?
    var onAddPreset: (() -> Void)?
    var onEditPreset: ((TimerPresetModel) -> Void)?
    var onDeletePreset: ((TimerPresetModel) -> Void)?

    // MARK: - Properties

    private var presets: [TimerPresetModel] = []
    private var isEditMode = false

    // MARK: - UI

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
        view.backgroundColor = DSColor.Neutral._0

        let title = UILabel().then {
            $0.text = "프리셋"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 18)
            $0.textColor = DSColor.textPrimary
        }
        let titleRow = UIStackView(arrangedSubviews: [title, UIView(), editButton]).then {
            $0.axis = .horizontal; $0.alignment = .center
        }
        let sub = UILabel().then {
            $0.text = "누르면 타이머가 바로 시작됩니다"
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
            $0.textColor = DSColor.textSecondary
        }
        let header = UIStackView(arrangedSubviews: [titleRow, sub]).then {
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
        renderList()
    }

    // MARK: - Render

    private func renderList() {
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for preset in presets {
            listStack.addArrangedSubview(makeRow(preset))
        }
        listStack.addArrangedSubview(makeAddRow())
    }

    private func makeRow(_ preset: TimerPresetModel) -> UIView {
        let row = UIControl().then {
            $0.backgroundColor = DSColor.Neutral._50
            $0.layer.cornerRadius = 12
            $0.layer.borderWidth = 1
            $0.layer.borderColor = DSColor.Neutral._200.cgColor
        }

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
            // 삭제(빨간 마이너스) + … + chevron (행 탭 = 편집)
            let minus = UIButton(type: .system).then {
                $0.setImage(
                    UIImage(systemName: "minus.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20)),
                    for: .normal
                )
                $0.tintColor = DSColor.Error._500
            }
            minus.snp.makeConstraints { $0.width.height.equalTo(22) }
            minus.addAction(UIAction { [weak self] _ in self?.onDeletePreset?(preset) }, for: .touchUpInside)
            leading = [minus]

            let chevron = UIImageView(image: DSIcon.chevronRight.uiImage).then {
                $0.tintColor = DSColor.Neutral._400
                $0.contentMode = .scaleAspectFit
            }
            chevron.snp.makeConstraints { $0.width.height.equalTo(18) }
            trailing = chevron

            row.addAction(UIAction { [weak self] _ in self?.onEditPreset?(preset) }, for: .touchUpInside)
        } else {
            let play = UIImageView().then {
                $0.image = UIImage(systemName: "play.circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .regular))
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
        let row = UIControl().then {
            $0.layer.cornerRadius = 12
            $0.layer.borderWidth = 1
            $0.layer.borderColor = DSColor.Neutral._300.cgColor
        }
        let plus = UIImageView(image: DSIcon.plus.uiImage).then {
            $0.tintColor = DSColor.textSecondary
            $0.contentMode = .scaleAspectFit
        }
        plus.snp.makeConstraints { $0.width.height.equalTo(16) }
        let label = UILabel().then {
            $0.text = "프리셋 추가"
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 14)
            $0.textColor = DSColor.textSecondary
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
