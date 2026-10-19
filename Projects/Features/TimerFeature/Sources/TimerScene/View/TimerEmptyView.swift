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
            $0.image = DSIcon.timer.uiImage
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

        // 볼록 파랑 버튼 + 아이콘 (V2.1.0)
        let startButton = PrimaryButton(title: "타이머 시작하기").setIcon(.plus)
        startButton.changeInset(top: 14, leading: 28, bottom: 14, trailing: 28)
        startButton.addAction(UIAction { [weak self] _ in self?.onStart?() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [circle, texts, startButton]).then {
            $0.axis = .vertical; $0.spacing = 20; $0.alignment = .center
        }
        addSubview(stack)
        // edges 로 고정해 뷰가 콘텐츠 크기를 갖게 한다.
        // (center 로만 잡으면 emptyView 높이가 0 이라 시작 버튼이 보이되 탭이 안 먹는다)
        stack.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}
