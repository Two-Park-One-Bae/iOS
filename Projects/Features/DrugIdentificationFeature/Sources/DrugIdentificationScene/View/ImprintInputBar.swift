import UIKit
import SnapKit
import Then
import DSKit

/// ⑧-e 각인 입력 — 키보드 위 화면 폭 입력 줄 + 기호 바 (DESIGN.pen NM-490 E-3).
///
/// 면 카드의 입력칸은 약 8자라 좁다 — 실제 입력은 여기서 하고, 확인하면 면 카드에 결과만 보인다.
/// **비우고 확인하면 `없음`**(각인 없는 알약만). 조건을 없애려면 드롭다운의 `전체` 를 고른다.
final class ImprintInputBar: UIView {

    /// 확인 — 입력한 글자(앞뒤 공백 제거 전).
    var onSubmit: ((String) -> Void)?

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

    private let faceLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 11)
        $0.textColor = DSColor.textTertiary
        $0.setContentHuggingPriority(.required, for: .horizontal)
    }
    private let symbolBar = ImprintSymbolBar()

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 44 + 52)
    }

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 96))
        autoresizingMask = .flexibleHeight
        backgroundColor = DSColor.surface
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 면 이름과 지금 값을 채운다. 모델값이어도 그대로 보여 주고, 고치면 사용자값이 된다.
    func prepare(faceTitle: String, text: String) {
        faceLabel.text = "\(faceTitle) 각인"
        field.text = text
        field.accessibilityLabel = "\(faceTitle) 각인 입력"
    }

    private func setup() {
        symbolBar.onSymbol = { [weak self] symbol in self?.field.insertText(symbol) }

        let inputBox = UIView().then {
            $0.backgroundColor = DSColor.Warning._50
            $0.layer.cornerRadius = 8
            $0.layer.borderWidth = 1
            $0.layer.borderColor = DSColor.Primary._500.cgColor
        }
        inputBox.addSubview(field)
        field.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 6)) }
        inputBox.snp.makeConstraints { $0.height.equalTo(36) }

        let confirm = UIButton(type: .system).then {
            $0.backgroundColor = DSColor.Primary._500
            $0.layer.cornerRadius = 8
            $0.setTitle("확인", for: .normal)
            $0.setTitleColor(DSColor.Neutral._0, for: .normal)
            $0.titleLabel?.font = DSKitFontFamily.Pretendard.bold.font(size: 13)
            $0.contentEdgeInsets = UIEdgeInsets(top: 7, left: 12, bottom: 7, right: 12)
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.addAction(UIAction { [weak self] _ in self?.submit() }, for: .touchUpInside)
        }
        field.addAction(UIAction { [weak self] _ in self?.submit() }, for: .editingDidEndOnExit)

        let row = UIStackView(arrangedSubviews: [faceLabel, inputBox, confirm]).then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.alignment = .center
        }
        let topLine = UIView().then { $0.backgroundColor = DSColor.Neutral._200 }

        addSubview(symbolBar)
        addSubview(topLine)
        addSubview(row)
        symbolBar.snp.makeConstraints { $0.top.leading.trailing.equalToSuperview(); $0.height.equalTo(44) }
        topLine.snp.makeConstraints { $0.top.equalTo(symbolBar.snp.bottom); $0.leading.trailing.equalToSuperview(); $0.height.equalTo(1) }
        row.snp.makeConstraints {
            $0.top.equalTo(topLine.snp.bottom).offset(8)
            $0.leading.trailing.equalToSuperview().inset(12)
            $0.bottom.equalTo(safeAreaLayoutGuide).inset(8)
        }
    }

    private func submit() {
        onSubmit?(field.text ?? "")
    }
}
