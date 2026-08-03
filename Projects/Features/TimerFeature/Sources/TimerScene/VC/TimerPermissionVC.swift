import UIKit
import SnapKit
import Then
import DSKit

// A3 알람 권한 — 안내(RG87P) / 거부(EgsrR) 바텀시트
// 인앱(TimerCoordinator)뿐 아니라 위젯 딥링크 시작(SceneDelegate)에서도 재사용하므로 public (NM-360).
public final class TimerPermissionVC: UIViewController {

    public enum Mode { case prompt, denied }

    // MARK: - Callbacks

    public var onAllow: (() -> Void)?         // prompt: 허용하고 시작하기
    public var onLater: (() -> Void)?         // prompt: 나중에 할게요
    public var onOpenSettings: (() -> Void)?  // denied: 설정에서 켜기
    public var onBack: (() -> Void)?          // denied: 닫기

    // MARK: - Properties

    private let mode: Mode

    // MARK: - Init

    public init(mode: Mode) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setLayout()
    }

    // MARK: - Layout

    private func setLayout() {
        view.backgroundColor = DSColor.Neutral._0

        let isPrompt = mode == .prompt

        // 아이콘 원 64 (prompt: Primary50 + bell / denied: Error50 + bell-off)
        let circle = UIView().then {
            $0.backgroundColor = isPrompt ? DSColor.Primary._50 : DSColor.Error._50
            $0.layer.cornerRadius = 32
        }
        let icon = UIImageView().then {
            $0.image = UIImage(
                systemName: isPrompt ? "bell.fill" : "bell.slash.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .regular)
            )
            $0.tintColor = isPrompt ? DSColor.Primary._600 : DSColor.Error._600
            $0.contentMode = .scaleAspectFit
        }
        circle.addSubview(icon)
        circle.snp.makeConstraints { $0.width.height.equalTo(64) }
        icon.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(30) }

        let title = UILabel().then {
            $0.text = isPrompt ? "알람 권한이 필요해요" : "알람이 꺼져 있어요"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 18)
            $0.textColor = DSColor.textPrimary
            $0.textAlignment = .center
        }
        let desc = UILabel().then {
            $0.text = isPrompt
                ? "타이머가 끝나면 시계 알람처럼 울려요.\n알람을 허용해야 타이머를 시작할 수 있어요."
                : "알람이 꺼져 있으면 타이머를 시작할 수 없어요.\n설정에서 널스메이트 알람을 허용해주세요."
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 14)
            $0.textColor = DSColor.textSecondary
            $0.textAlignment = .center
            $0.numberOfLines = 0
        }
        let texts = UIStackView(arrangedSubviews: [title, desc]).then {
            $0.axis = .vertical; $0.spacing = 8; $0.alignment = .center
        }

        let primaryButton = PrimaryButton(title: isPrompt ? "허용하고 시작하기" : "설정에서 켜기")
        let secondaryButton = UIButton(type: .system).then {
            $0.setTitle(isPrompt ? "나중에 할게요" : "닫기", for: .normal)
            $0.setTitleColor(DSColor.textSecondary, for: .normal)
            $0.titleLabel?.font = DSKitFontFamily.Pretendard.medium.font(size: 14)
        }

        primaryButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.mode == .prompt ? self.onAllow?() : self.onOpenSettings?()
        }, for: .touchUpInside)
        secondaryButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.mode == .prompt ? self.onLater?() : self.onBack?()
        }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [circle, texts, primaryButton, secondaryButton]).then {
            $0.axis = .vertical
            $0.spacing = 16
            $0.alignment = .center
        }
        view.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(24)
            $0.leading.trailing.equalToSuperview().inset(24)
        }
        primaryButton.snp.makeConstraints { $0.leading.trailing.equalTo(stack) }
    }
}
