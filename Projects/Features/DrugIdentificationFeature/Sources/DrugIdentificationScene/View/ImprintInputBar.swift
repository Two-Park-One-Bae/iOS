import UIKit
import SnapKit
import Then
import DSKit

/// ⑧ 각인 입력 — 키보드 위 화면 폭 입력 줄 + 기호 바 (V2.1.0 NM-588 ⑨ · ⑩).
///
/// 두 층이다 — 윗줄 `[입력 칸] [확인]`, 아랫줄 `[원래 값] [모름] [각인 없음]` — 그 아래 기호 바.
/// - 입력 칸이 비면 `확인`을 누를 수 없다. 각인 없는 알약은 `각인 없음`, 조건을 두지 않으려면 `모름`.
///   두 버튼은 누르면 바로 입력 줄을 닫는다.
/// - `원래 값`(사진에서 읽은 각인)은 고쳤을 때만 보인다.
/// - 입력 줄에는 라벨이 없다 — 칸이 비었을 때 안내 글자(`앞면 각인` · `뒷면 각인`)로 면을 알린다.
final class ImprintInputBar: UIView {

    /// 확인 — 입력한 글자(앞뒤 공백 제거 전). 빈 글자로는 부르지 않는다.
    var onSubmit: ((String) -> Void)?
    var onUnknown: (() -> Void)?
    var onNone: (() -> Void)?
    /// 사진에서 읽은 각인으로 되돌린다.
    var onRevert: (() -> Void)?

    let field = UITextField().then {
        $0.font = DSKitFontFamily.Pretendard.extraBold.font(size: 16)
        $0.textColor = DSColor.textPrimary
        $0.autocapitalizationType = .allCharacters
        $0.autocorrectionType = .no
        $0.spellCheckingType = .no
        $0.keyboardType = .asciiCapable
        $0.returnKeyType = .done
        $0.clearButtonMode = .whileEditing
    }

    private let confirmButton = PrimaryButton(title: "확인")
    private let revertButton = ImprintOptionButton(title: "원래 값", icon: .restart)
    private let unknownButton = ImprintOptionButton(title: "모름", icon: nil)
    private let noneButton = ImprintOptionButton(title: "각인 없음", icon: nil)
    private let symbolBar = ImprintSymbolBar()

    private static let height: CGFloat = 52 + 40 + 44

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Self.height)
    }

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: Self.height))
        autoresizingMask = .flexibleHeight
        backgroundColor = DSColor.surface
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 지금 값을 채운다. 모델값이어도 그대로 보여 주고, 고치면 사용자값이 된다.
    /// - Parameter originalValue: 사진에서 읽은 각인 — 고친 뒤에만 넘긴다(nil이면 `원래 값`을 숨긴다).
    func prepare(placeholder: String, text: String, originalValue: String?) {
        field.text = text
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: DSColor.textTertiary,
                .font: DSKitFontFamily.Pretendard.regular.font(size: 15)
            ]
        )
        field.accessibilityLabel = "\(placeholder) 입력"
        revertButton.isHidden = originalValue == nil
        revertButton.accessibilityValue = originalValue
        updateConfirm()
    }

    private func setup() {
        symbolBar.onSymbol = { [weak self] symbol in
            self?.field.insertText(symbol)
            self?.updateConfirm()
        }

        // 윗줄 — 입력 칸(파란 테두리, 캡슐) + 확인
        let inputBox = UIView().then {
            $0.backgroundColor = DSColor.surface
            $0.layer.cornerRadius = 20
            $0.layer.borderWidth = 1.5
            $0.layer.borderColor = DSColor.Primary._500.cgColor
        }
        inputBox.addSubview(field)
        field.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 8)) }
        inputBox.snp.makeConstraints { $0.height.equalTo(40) }

        confirmButton.changeInset(top: 0, leading: 16, bottom: 0, trailing: 16)
        confirmButton.setCapsule()
        confirmButton.snp.makeConstraints { $0.height.equalTo(40) }
        confirmButton.setContentHuggingPriority(.required, for: .horizontal)
        confirmButton.addAction(UIAction { [weak self] _ in self?.submit() }, for: .touchUpInside)
        field.addAction(UIAction { [weak self] _ in self?.submit() }, for: .editingDidEndOnExit)
        field.addAction(UIAction { [weak self] _ in self?.updateConfirm() }, for: .editingChanged)

        let inputRow = UIStackView(arrangedSubviews: [inputBox, confirmButton]).then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.alignment = .center
        }

        // 아랫줄 — 원래 값 · 모름 · 각인 없음
        revertButton.addAction(UIAction { [weak self] _ in self?.onRevert?() }, for: .touchUpInside)
        unknownButton.addAction(UIAction { [weak self] _ in self?.onUnknown?() }, for: .touchUpInside)
        noneButton.addAction(UIAction { [weak self] _ in self?.onNone?() }, for: .touchUpInside)
        let optionRow = UIStackView(arrangedSubviews: [revertButton, unknownButton, noneButton, UIView()]).then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.alignment = .center
        }

        let topLine = UIView().then { $0.backgroundColor = DSColor.Neutral._200 }
        [topLine, inputRow, optionRow, symbolBar].forEach(addSubview)
        topLine.snp.makeConstraints { $0.top.leading.trailing.equalToSuperview(); $0.height.equalTo(1) }
        inputRow.snp.makeConstraints {
            $0.top.equalToSuperview().offset(6)
            $0.leading.trailing.equalToSuperview().inset(12)
        }
        optionRow.snp.makeConstraints {
            $0.top.equalTo(inputRow.snp.bottom).offset(6)
            $0.leading.trailing.equalToSuperview().inset(12)
            $0.height.equalTo(30)
        }
        symbolBar.snp.makeConstraints {
            $0.top.equalTo(optionRow.snp.bottom).offset(4)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(44)
            $0.bottom.equalTo(safeAreaLayoutGuide)
        }
    }

    private var trimmedText: String {
        (field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateConfirm() {
        confirmButton.setEnabled(!trimmedText.isEmpty)
    }

    private func submit() {
        guard !trimmedText.isEmpty else { return }
        onSubmit?(field.text ?? "")
    }
}

/// 입력 줄 아랫줄의 선택 버튼 — 흰 볼록 캡슐, 높이 30, Medium 13.
private final class ImprintOptionButton: UIButton {

    private let surface = DSSurfaceView(spec: .raisedNeutral(), cornerRadius: nil)

    init(title: String, icon: DSIcon?) {
        super.init(frame: .zero)
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = DSColor.textPrimary
        config.background.backgroundColor = .clear
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        config.imagePadding = 4
        config.image = icon?.uiImage(size: 16)
        var attributed = AttributedString(title)
        attributed.font = DSKitFontFamily.Pretendard.medium.font(size: 13)
        config.attributedTitle = attributed
        configuration = config

        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(surface, at: 0)
        snp.makeConstraints { $0.height.equalTo(30) }

        configurationUpdateHandler = { [weak self] button in
            self?.surface.alpha = button.isHighlighted ? 0.85 : 1
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    // 높이 30 칩이지만 누르는 영역은 44 로 잡는다.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: 0, dy: -7).contains(point)
    }
}
