import UIKit
import SnapKit
import Then
import DSKit
import Domain

// ⑧-e 각인 입력 — 앞/뒤 각인 텍스트 + 해당없음 + 구분선 + 마크 (Neutral100 카드)
final class ImprintEditorPanel: UIView {

    var onChange: ((_ front: PillFaceModel?, _ back: PillFaceModel?) -> Void)?

    private let frontEditor: FaceEditor
    private let backEditor: FaceEditor

    init(front: PillFaceModel?, back: PillFaceModel?) {
        frontEditor = FaceEditor(title: "앞면 (사진 면)", model: front)
        backEditor = FaceEditor(title: "뒷면", model: back)
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = DSColor.Neutral._100
        layer.cornerRadius = 12

        let notify: () -> Void = { [weak self] in
            guard let self else { return }
            self.onChange?(self.frontEditor.model, self.backEditor.model)
        }
        frontEditor.onChange = notify
        backEditor.onChange = notify

        let divider = UIView().then { $0.backgroundColor = DSColor.Neutral._200 }
        let stack = UIStackView(arrangedSubviews: [frontEditor, divider, backEditor]).then {
            $0.axis = .vertical
            $0.spacing = 12
        }
        divider.snp.makeConstraints { $0.height.equalTo(1) }
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(12) }
    }

    // MARK: - Face Editor

    final class FaceEditor: UIView, UITextFieldDelegate {
        var onChange: (() -> Void)?
        private(set) var model: PillFaceModel?

        private let textField = UITextField()
        private let fieldBox = UIView()
        private let noImprintCheck = CheckboxView(text: "해당 없음")
        private let dividerSeg = DividerSegment()
        private let markCheck = CheckboxView(text: "마크 있음")
        private let inputContainer = UIStackView()

        init(title: String, model: PillFaceModel?) {
            self.model = model
            super.init(frame: .zero)
            setup(title: title, model: model)
        }
        required init?(coder: NSCoder) { fatalError() }

        private func setup(title: String, model: PillFaceModel?) {
            let titleLabel = UILabel().then {
                $0.text = title
                $0.font = DSKitFontFamily.Pretendard.bold.font(size: 13)
                $0.textColor = DSColor.textPrimary
            }
            noImprintCheck.setChecked(model?.imprint?.isEmpty ?? true)
            noImprintCheck.onToggle = { [weak self] on in self?.setNoImprint(on) }
            let header = UIStackView(arrangedSubviews: [titleLabel, UIView(), noImprintCheck]).then {
                $0.axis = .horizontal; $0.alignment = .center
            }

            // Field
            fieldBox.backgroundColor = DSColor.Neutral._0
            fieldBox.layer.cornerRadius = 10
            fieldBox.layer.borderWidth = 1
            fieldBox.layer.borderColor = DSColor.Neutral._200.cgColor
            textField.font = DSKitFontFamily.Pretendard.regular.font(size: 15)
            textField.textColor = DSColor.textPrimary
            textField.text = model?.imprint
            textField.autocapitalizationType = .allCharacters
            textField.returnKeyType = .done
            textField.delegate = self
            textField.attributedPlaceholder = NSAttributedString(
                string: "각인 입력",
                attributes: [.foregroundColor: DSColor.Neutral._400,
                             .font: DSKitFontFamily.Pretendard.regular.font(size: 15)]
            )
            textField.addTarget(self, action: #selector(fieldChanged), for: .editingChanged)
            textField.addTarget(self, action: #selector(fieldFocus), for: .editingDidBegin)
            textField.addTarget(self, action: #selector(fieldBlur), for: .editingDidEnd)

            // 키보드 위 기호 바
            let symbolBar = ImprintSymbolBar()
            symbolBar.onSymbol = { [weak self] symbol in self?.insertSymbol(symbol) }
            textField.inputAccessoryView = symbolBar
            fieldBox.addSubview(textField)
            textField.snp.makeConstraints {
                $0.top.bottom.equalToSuperview().inset(11)
                $0.leading.trailing.equalToSuperview().inset(12)
            }

            // Controls
            let dividerLabel = UILabel().then {
                $0.text = "구분선"
                $0.font = DSKitFontFamily.Pretendard.medium.font(size: 12)
                $0.textColor = DSColor.textSecondary
            }
            switch model?.dividingLine {
            case .plus:  dividerSeg.select(2)
            case .minus: dividerSeg.select(1)
            default:     dividerSeg.select(0)
            }
            dividerSeg.onChange = { [weak self] _ in self?.emit() }
            let dividerRow = UIStackView(arrangedSubviews: [dividerLabel, dividerSeg]).then {
                $0.axis = .horizontal; $0.spacing = 8; $0.alignment = .center
            }

            markCheck.setChecked(model?.hasMark ?? false)
            markCheck.onToggle = { [weak self] _ in self?.emit() }

            let controls = UIStackView(arrangedSubviews: [dividerRow, UIView(), markCheck]).then {
                $0.axis = .horizontal; $0.alignment = .center
            }

            // 입력부 (해당 없음 체크 시 접힘)
            inputContainer.axis = .vertical
            inputContainer.spacing = 10
            inputContainer.addArrangedSubview(fieldBox)
            inputContainer.addArrangedSubview(controls)
            inputContainer.isHidden = noImprintCheck.isChecked

            let stack = UIStackView(arrangedSubviews: [header, inputContainer]).then {
                $0.axis = .vertical; $0.spacing = 10
            }
            addSubview(stack)
            stack.snp.makeConstraints { $0.edges.equalToSuperview() }
        }

        private func setNoImprint(_ on: Bool) {
            inputContainer.isHidden = on
            if on {
                textField.text = nil
                textField.resignFirstResponder()
            }
            textField.isEnabled = !on
            emit()
        }

        @objc private func fieldChanged() {
            if textField.text?.isEmpty == false { noImprintCheck.setChecked(false) }
            emit()
        }

        // 기호 바에서 커서 위치에 기호 삽입
        private func insertSymbol(_ symbol: String) {
            guard textField.isEnabled else { return }
            if let range = textField.selectedTextRange {
                textField.replace(range, withText: symbol)
            } else {
                textField.text = (textField.text ?? "") + symbol
            }
            fieldChanged()
        }
        @objc private func fieldFocus() { fieldBox.layer.borderColor = DSColor.Primary._500.cgColor; fieldBox.layer.borderWidth = 1.5 }
        @objc private func fieldBlur() { fieldBox.layer.borderColor = DSColor.Neutral._200.cgColor; fieldBox.layer.borderWidth = 1 }

        private func emit() {
            let imprint = (textField.isEnabled && textField.text?.isEmpty == false) ? textField.text : nil
            let line: DividingLineModel?
            switch dividerSeg.selectedIndex {
            case 1:  line = .minus
            case 2:  line = .plus
            default: line = nil
            }
            model = PillFaceModel(imprint: imprint, dividingLine: line, hasMark: markCheck.isChecked)
            onChange?()
        }

        // 리턴키(완료) → 키보드 내림
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }

    // MARK: - Checkbox

    final class CheckboxView: UIControl {
        private(set) var isChecked = false
        var onToggle: ((Bool) -> Void)?

        private let box = UIView()
        private let check = UIImageView(image: UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 9, weight: .bold)))
        private let label = UILabel()

        init(text: String) {
            super.init(frame: .zero)
            box.layer.cornerRadius = 4
            box.layer.borderWidth = 1.5
            box.isUserInteractionEnabled = false
            check.tintColor = DSColor.Neutral._0
            check.contentMode = .center
            check.isHidden = true
            box.addSubview(check)
            box.snp.makeConstraints { $0.width.height.equalTo(16) }
            check.snp.makeConstraints { $0.edges.equalToSuperview() }

            label.text = text
            label.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
            label.textColor = DSColor.textPrimary
            label.isUserInteractionEnabled = false

            let stack = UIStackView(arrangedSubviews: [box, label]).then {
                $0.axis = .horizontal; $0.spacing = 6; $0.alignment = .center
                $0.isUserInteractionEnabled = false
            }
            addSubview(stack)
            stack.snp.makeConstraints { $0.edges.equalToSuperview() }
            addTarget(self, action: #selector(tapped), for: .touchUpInside)
            applyStyle()
        }
        required init?(coder: NSCoder) { fatalError() }

        @objc private func tapped() {
            isChecked.toggle()
            applyStyle()
            onToggle?(isChecked)
        }
        func setChecked(_ checked: Bool) {
            guard checked != isChecked else { return }
            isChecked = checked
            applyStyle()
        }
        private func applyStyle() {
            check.isHidden = !isChecked
            box.backgroundColor = isChecked ? DSColor.Primary._500 : .clear
            box.layer.borderColor = (isChecked ? DSColor.Primary._500 : DSColor.Neutral._400).cgColor
        }
    }

    // MARK: - Divider Segment (없음 / − / +)

    final class DividerSegment: UIView {
        private(set) var selectedIndex = 0
        var onChange: ((Int) -> Void)?

        private var cells: [UIView] = []
        private var labels: [UILabel] = []
        private let titles = ["없음", "−", "+"]

        init() {
            super.init(frame: .zero)
            layer.cornerRadius = 8
            layer.borderWidth = 1
            layer.borderColor = DSColor.Neutral._200.cgColor
            clipsToBounds = true

            let row = UIStackView().then { $0.axis = .horizontal }
            for (i, title) in titles.enumerated() {
                let cell = UIControl()
                let lb = UILabel().then {
                    $0.text = title
                    $0.textAlignment = .center
                    $0.isUserInteractionEnabled = false
                }
                cell.addSubview(lb)
                lb.snp.makeConstraints {
                    $0.top.bottom.equalToSuperview().inset(6)
                    $0.leading.trailing.equalToSuperview().inset(12)
                }
                cell.addAction(UIAction { [weak self] _ in self?.tap(i) }, for: .touchUpInside)
                cells.append(cell)
                labels.append(lb)
                row.addArrangedSubview(cell)
            }
            addSubview(row)
            row.snp.makeConstraints { $0.edges.equalToSuperview() }
            applyStyle()
        }
        required init?(coder: NSCoder) { fatalError() }

        func select(_ index: Int) { selectedIndex = index; applyStyle() }
        private func tap(_ index: Int) { selectedIndex = index; applyStyle(); onChange?(index) }

        private func applyStyle() {
            for (i, cell) in cells.enumerated() {
                let on = i == selectedIndex
                cell.backgroundColor = on ? DSColor.Primary._50 : DSColor.Neutral._0
                labels[i].textColor = on ? DSColor.Primary._600 : DSColor.textSecondary
                labels[i].font = on
                    ? DSKitFontFamily.Pretendard.bold.font(size: 13)
                    : DSKitFontFamily.Pretendard.regular.font(size: 13)
            }
        }
    }
}
