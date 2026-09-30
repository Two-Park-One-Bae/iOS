import UIKit
import SnapKit
import Then
import DSKit

// 각인 입력 키보드 위 기호 바 — inputAccessoryView
//
// 기호 9종의 정본은 spec `feature/pill-recognition/README.md` 「기호 바 (NM-523)」다.
// = 각인 정규화 허용 기호 8종 + ∧ (정규화가 Λ · ∧ · λ 를 A 로 접는다 — DB 각인이 대부분 Λ).
// ○ 는 정규화가 0 으로 접어 O · 0 입력과 같아지고, ∨ 는 DB 각인이 0면이라 두지 않는다.
// 목록을 바꾸면 디자인 · Android PillSymbolBar · 서버 ImprintNormalizer 도 함께 고친다.
final class ImprintSymbolBar: UIView {

    var onSymbol: ((String) -> Void)?

    private let symbols = ["△", "▽", "∧", "∩", "∪", "★", "☆", "↑", "♡"]

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 44)
    }

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        autoresizingMask = .flexibleWidth
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = UIColor(red: 228 / 255, green: 231 / 255, blue: 236 / 255, alpha: 1) // #E4E7EC

        let topBorder = UIView().then { $0.backgroundColor = DSColor.Neutral._200 }
        addSubview(topBorder)
        topBorder.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(1)
        }

        let stack = UIStackView().then {
            $0.axis = .horizontal
            $0.distribution = .equalSpacing
            $0.alignment = .center
        }
        for symbol in symbols {
            stack.addArrangedSubview(makeKey(symbol))
        }
        addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(8)
            $0.leading.trailing.equalToSuperview().inset(12)
        }
    }

    private func makeKey(_ symbol: String) -> UIView {
        let key = UIButton(type: .system).then {
            $0.backgroundColor = DSColor.Neutral._0
            $0.layer.cornerRadius = 7
            $0.setTitle(symbol, for: .normal)
            $0.setTitleColor(DSColor.textPrimary, for: .normal)
            $0.titleLabel?.font = .systemFont(ofSize: 16)
            $0.layer.shadowColor = DSColor.textPrimary.cgColor
            $0.layer.shadowOpacity = 0.08
            $0.layer.shadowOffset = CGSize(width: 0, height: 1)
            $0.layer.shadowRadius = 1
        }
        key.snp.makeConstraints { $0.width.height.equalTo(26) }
        key.addAction(UIAction { [weak self] _ in self?.onSymbol?(symbol) }, for: .touchUpInside)
        return key
    }
}
