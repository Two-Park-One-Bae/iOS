import UIKit
import SnapKit
import Then
import DSKit
import Domain

// ZFXjS — 타이머 만료 풀스크린 알람 (포그라운드).
// 시스템 로컬 알림은 작은 배너로만 뜨기 때문에, 앱이 켜져 있을 때는 이 화면이
// 전체화면으로 떠서 루핑 사운드와 함께 울린다. [완료]/[+5분]으로만 종료.
public final class TimerRingingAlarmViewController: UIViewController {

    public var onSnooze: (() -> Void)?
    public var onComplete: (() -> Void)?

    private let timer: TreatmentTimerModel

    public init(timer: TreatmentTimerModel) {
        self.timer = timer
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    private func setup() {
        view.backgroundColor = UIColor(hex: 0x0F172A)

        // MARK: Top — 앱 표식 + 제목 + 본문
        let appIcon = UIView().then {
            $0.backgroundColor = DSColor.Primary._500
            $0.layer.cornerRadius = 6
        }
        appIcon.snp.makeConstraints { $0.width.height.equalTo(24) }
        let appName = UILabel().then {
            $0.text = "널스메이트"
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 14)
            $0.textColor = UIColor(hex: 0x94A3B8)
        }
        let appRow = UIStackView(arrangedSubviews: [appIcon, appName]).then {
            $0.axis = .horizontal; $0.spacing = 8; $0.alignment = .center
        }
        let titleLabel = UILabel().then {
            $0.text = "\(timer.label) 종료"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 24)
            $0.textColor = UIColor(hex: 0xF8FAFC)
            $0.textAlignment = .center
        }
        let bodyLabel = UILabel().then {
            $0.text = "\(TimerFormat.duration(timer.duration)) 타이머가 끝났어요"
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 15)
            $0.textColor = UIColor(hex: 0x94A3B8)
            $0.textAlignment = .center
        }
        let topStack = UIStackView(arrangedSubviews: [appRow, titleLabel, bodyLabel]).then {
            $0.axis = .vertical; $0.spacing = 12; $0.alignment = .center
        }

        // MARK: Bell — 큰 벨 + "알람이 울리는 중"
        let bellIcon = UIImageView().then {
            $0.image = UIImage(
                systemName: "bell.and.waves.left.and.right",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 50, weight: .regular)
            )
            $0.tintColor = DSColor.Warning._500
            $0.contentMode = .scaleAspectFit
        }
        let bellWrap = UIView().then {
            $0.backgroundColor = UIColor(hex: 0x1E293B)
            $0.layer.cornerRadius = 60
        }
        bellWrap.addSubview(bellIcon)
        bellIcon.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(52) }
        bellWrap.snp.makeConstraints { $0.width.height.equalTo(120) }
        let ringingLabel = UILabel().then {
            $0.text = "알람이 울리는 중"
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
            $0.textColor = UIColor(hex: 0x64748B)
        }
        let bellStack = UIStackView(arrangedSubviews: [bellWrap, ringingLabel]).then {
            $0.axis = .vertical; $0.spacing = 16; $0.alignment = .center
        }

        // MARK: Actions — [+5분] [완료]
        let snooze = makeAction(fill: UIColor(hex: 0x334155), icon: "gobackward", caption: "+5분")
        let complete = makeAction(fill: DSColor.Warning._600, icon: "checkmark", caption: "완료")
        snooze.button.addAction(UIAction { [weak self] _ in self?.onSnooze?() }, for: .touchUpInside)
        complete.button.addAction(UIAction { [weak self] _ in self?.onComplete?() }, for: .touchUpInside)
        let actions = UIStackView(arrangedSubviews: [snooze.stack, complete.stack]).then {
            $0.axis = .horizontal; $0.spacing = 80; $0.alignment = .top
        }

        let root = UIStackView(arrangedSubviews: [topStack, bellStack, actions]).then {
            $0.axis = .vertical
            $0.distribution = .equalSpacing
        }
        view.addSubview(root)
        root.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(64)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(48)
            $0.leading.trailing.equalToSuperview().inset(24)
        }
    }

    private func makeAction(fill: UIColor, icon: String, caption: String) -> (stack: UIStackView, button: UIControl) {
        let button = UIControl().then {
            $0.backgroundColor = fill
            $0.layer.cornerRadius = 38
        }
        let iv = UIImageView().then {
            $0.image = UIImage(
                systemName: icon,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
            )
            $0.tintColor = .white
            $0.contentMode = .scaleAspectFit
            $0.isUserInteractionEnabled = false
        }
        button.addSubview(iv)
        iv.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(30) }
        button.snp.makeConstraints { $0.width.height.equalTo(76) }
        let cap = UILabel().then {
            $0.text = caption
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
            $0.textColor = UIColor(hex: 0x94A3B8)
            $0.textAlignment = .center
        }
        let stack = UIStackView(arrangedSubviews: [button, cap]).then {
            $0.axis = .vertical; $0.spacing = 10; $0.alignment = .center
        }
        return (stack, button)
    }
}

// MARK: - Hex 색 (ZFXjS 다크 팔레트 — DSKit에 없는 값)
private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }
}
