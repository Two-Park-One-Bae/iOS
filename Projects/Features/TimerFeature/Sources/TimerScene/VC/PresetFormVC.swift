import UIKit
import SnapKit
import Then
import DSKit
import Domain

// C3 프리셋 추가(B5lCW)/편집(OvUo6) — 처치 키워드 + 분류 + 시·분·초 휠 피커
final class PresetFormVC: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    // MARK: - Callbacks

    var onSave: ((_ label: String, _ category: TimerCategory, _ duration: Int) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - Properties

    let editingPreset: TimerPresetModel?
    private var selectedCategory: TimerCategory?

    // MARK: - UI

    private let keywordField = DSTextField(label: "처치 키워드", placeholder: "예: 수혈 교체")
    private var categoryButtons: [TimerCategory: UIControl] = [:]
    private var categoryLabels: [TimerCategory: UILabel] = [:]
    private let picker = UIPickerView()
    private let saveButton = PrimaryButton(title: "저장")

    // MARK: - Init

    init(preset: TimerPresetModel?) {
        self.editingPreset = preset
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setLayout()
        prefillIfNeeded()
        validate()
    }

    // MARK: - Layout

    private func setLayout() {
        view.backgroundColor = DSColor.Neutral._0

        // Header: 제목 + ✕
        let title = UILabel().then {
            $0.text = editingPreset == nil ? "프리셋 추가" : "프리셋 편집"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 18)
            $0.textColor = DSColor.textPrimary
        }
        let close = UIButton(type: .system).then {
            $0.setImage(DSIcon.xMark.uiImage, for: .normal)
            $0.tintColor = DSColor.textSecondary
        }
        close.snp.makeConstraints { $0.width.height.equalTo(22) }
        close.addAction(UIAction { [weak self] _ in self?.onCancel?() }, for: .touchUpInside)
        let header = UIStackView(arrangedSubviews: [title, UIView(), close]).then {
            $0.axis = .horizontal; $0.alignment = .center
        }

        // 분류
        let categoryLabel = UILabel().then {
            $0.text = "분류"
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 13)
            $0.textColor = DSColor.textSecondary
        }
        let categoryRow = UIStackView().then {
            $0.axis = .horizontal; $0.spacing = 8; $0.distribution = .fillEqually
        }
        for category in TimerCategory.allCases {
            let button = UIControl().then {
                $0.backgroundColor = DSColor.Neutral._50
                $0.layer.cornerRadius = 10
                $0.layer.borderWidth = 1
                $0.layer.borderColor = DSColor.Neutral._200.cgColor
            }
            let label = UILabel().then {
                $0.text = category.displayName
                $0.font = DSKitFontFamily.Pretendard.medium.font(size: 14)
                $0.textColor = DSColor.textSecondary
                $0.textAlignment = .center
                $0.isUserInteractionEnabled = false
            }
            button.addSubview(label)
            label.snp.makeConstraints {
                $0.top.bottom.equalToSuperview().inset(10)
                $0.leading.trailing.equalToSuperview().inset(8)
            }
            button.addAction(UIAction { [weak self] _ in self?.selectCategory(category) }, for: .touchUpInside)
            categoryButtons[category] = button
            categoryLabels[category] = label
            categoryRow.addArrangedSubview(button)
        }
        let categorySection = UIStackView(arrangedSubviews: [categoryLabel, categoryRow]).then {
            $0.axis = .vertical; $0.spacing = 6
        }

        // 시간 (시·분·초 휠)
        let timeLabel = UILabel().then {
            $0.text = "시간"
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 13)
            $0.textColor = DSColor.textSecondary
        }
        picker.dataSource = self
        picker.delegate = self
        picker.snp.makeConstraints { $0.height.equalTo(150) }
        let timeSection = UIStackView(arrangedSubviews: [timeLabel, picker]).then {
            $0.axis = .vertical; $0.spacing = 2
        }

        keywordField.textField.addTarget(self, action: #selector(fieldChanged), for: .editingChanged)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [header, keywordField, categorySection, timeSection, saveButton]).then {
            $0.axis = .vertical
            $0.spacing = 16
        }
        view.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(24)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
    }

    private func prefillIfNeeded() {
        guard let preset = editingPreset else { return }
        keywordField.text = preset.label
        selectCategory(preset.category)
        let h = preset.duration / 3600
        let m = (preset.duration % 3600) / 60
        let s = preset.duration % 60
        picker.selectRow(h, inComponent: 0, animated: false)
        picker.selectRow(m, inComponent: 1, animated: false)
        picker.selectRow(s, inComponent: 2, animated: false)
    }

    // MARK: - Actions

    private func selectCategory(_ category: TimerCategory) {
        selectedCategory = category
        for (key, button) in categoryButtons {
            let on = key == category
            button.backgroundColor = on ? DSColor.Primary._50 : DSColor.Neutral._50
            button.layer.borderColor = (on ? DSColor.Primary._500 : DSColor.Neutral._200).cgColor
            button.layer.borderWidth = on ? 1.5 : 1
            categoryLabels[key]?.textColor = on ? DSColor.Primary._600 : DSColor.textSecondary
            categoryLabels[key]?.font = on
                ? DSKitFontFamily.Pretendard.semiBold.font(size: 14)
                : DSKitFontFamily.Pretendard.medium.font(size: 14)
        }
        validate()
    }

    @objc private func fieldChanged() { validate() }

    @objc private func saveTapped() {
        guard let category = selectedCategory,
              let label = keywordField.text?.trimmingCharacters(in: .whitespaces),
              !label.isEmpty else { return }
        onSave?(label, category, currentDuration())
    }

    private func currentDuration() -> Int {
        picker.selectedRow(inComponent: 0) * 3600
            + picker.selectedRow(inComponent: 1) * 60
            + picker.selectedRow(inComponent: 2)
    }

    private func validate() {
        let labelOK = !(keywordField.text?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
        let valid = labelOK && selectedCategory != nil && currentDuration() > 0
        saveButton.setEnabled(valid)
    }

    // MARK: - UIPickerView (시 / 분 / 초)

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 3 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        component == 0 ? 24 : 60
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = (view as? UILabel) ?? UILabel()
        let unit = ["시간", "분", "초"][component]
        label.text = component == 0 ? "\(row) \(unit)" : String(format: "%02d %@", row, unit)
        label.font = DSKitFontFamily.Pretendard.semiBold.font(size: 17)
        label.textColor = DSColor.textPrimary
        label.textAlignment = .center
        return label
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        validate()
    }
}
