import UIKit
import SnapKit
import Then
import DSKit

// C1 빈 상태 (UOiCJ) — 타이머 아이콘 원 + 안내 + 시작 버튼
final class TimerEmptyView: UIView {

    var onStart: (() -> Void)?

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        let circle = UIView().then {
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = 48
        }
        let icon = UIImageView().then {
            $0.image = UIImage(systemName: "timer", withConfiguration: UIImage.SymbolConfiguration(pointSize: 38, weight: .regular))
            $0.tintColor = DSColor.Neutral._400
            $0.contentMode = .scaleAspectFit
        }
        circle.addSubview(icon)
        circle.snp.makeConstraints { $0.width.height.equalTo(96) }
        icon.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(44) }

        let title = UILabel().then {
            $0.text = "진행 중인 타이머가 없어요"
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 17)
            $0.textColor = DSColor.textPrimary
        }
        let sub = UILabel().then {
            $0.text = "프리셋을 눌러 바로 시작할 수 있어요"
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
            $0.textColor = DSColor.textSecondary
        }
        let texts = UIStackView(arrangedSubviews: [title, sub]).then {
            $0.axis = .vertical; $0.spacing = 8; $0.alignment = .center
        }

        let startButton = UIControl().then {
            $0.backgroundColor = DSColor.Primary._500
            $0.layer.cornerRadius = 12
        }
        let plus = UIImageView(image: DSIcon.plus.uiImage).then {
            $0.tintColor = DSColor.Neutral._0
            $0.contentMode = .scaleAspectFit
        }
        plus.snp.makeConstraints { $0.width.height.equalTo(18) }
        let startLabel = UILabel().then {
            $0.text = "타이머 시작하기"
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 16)
            $0.textColor = DSColor.Neutral._0
        }
        let startStack = UIStackView(arrangedSubviews: [plus, startLabel]).then {
            $0.axis = .horizontal; $0.spacing = 8; $0.alignment = .center
            $0.isUserInteractionEnabled = false
        }
        startButton.addSubview(startStack)
        startStack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(14)
            $0.leading.trailing.equalToSuperview().inset(28)
        }
        startButton.addAction(UIAction { [weak self] _ in self?.onStart?() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [circle, texts, startButton]).then {
            $0.axis = .vertical; $0.spacing = 20; $0.alignment = .center
        }
        addSubview(stack)
        stack.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.greaterThanOrEqualToSuperview()
            $0.trailing.lessThanOrEqualToSuperview()
        }
    }
}
