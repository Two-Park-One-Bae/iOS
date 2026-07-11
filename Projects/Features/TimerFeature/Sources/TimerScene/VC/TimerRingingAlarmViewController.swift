import UIKit
import SnapKit
import Then
import DSKit
import Domain

// ZFXjS — 타이머 만료 풀스크린 알람 (포그라운드).
// 시스템 로컬 알림은 작은 배너로만 뜨기 때문에, 앱이 켜져 있을 때는 이 화면이
// 전체화면으로 떠서 루핑 사운드와 함께 울린다. [완료]로만 종료.
//
// 리프레시 디자인(LA 만료 Km53q 톤): 순수 검정 배경 + 앰버(#F59E0B) 강조 +
// 벨 뒤 펄스 링 애니메이션으로 "울리는 중" 에너지를 준다.
public final class TimerRingingAlarmViewController: UIViewController {

    public var onComplete: (() -> Void)?

    private let timer: TreatmentTimerModel
    private let pulse = PulseRingView()

    // 팔레트 (Km53q — DSKit 미보유 값)
    private enum Palette {
        static let background = UIColor(hex: 0x000000)
        static let amber = UIColor(hex: 0xF59E0B)
        static let textPrimary = UIColor(hex: 0xF8FAFC)
        static let textSecondary = UIColor(hex: 0x94A3B8)
    }

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

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        pulse.start()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pulse.stop()
    }

    private func setup() {
        view.backgroundColor = Palette.background

        let header = makeHeader()
        let hero = makeHero()
        let actions = makeActions()

        let root = UIStackView(arrangedSubviews: [header, hero, actions]).then {
            $0.axis = .vertical
            $0.alignment = .fill
            $0.distribution = .equalSpacing
        }
        view.addSubview(root)
        root.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(56)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(40)
            $0.leading.trailing.equalToSuperview().inset(24)
        }
    }

    // MARK: - Header — 앱 표식 + 분류 칩

    private func makeHeader() -> UIView {
        let appIcon = UIView().then {
            $0.backgroundColor = DSColor.Primary._500
            $0.layer.cornerRadius = 6
        }
        appIcon.snp.makeConstraints { $0.width.height.equalTo(24) }

        let appName = UILabel().then {
            $0.text = "널스메이트"
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 14)
            $0.textColor = Palette.textSecondary
        }
        let appRow = UIStackView(arrangedSubviews: [appIcon, appName]).then {
            $0.axis = .horizontal; $0.spacing = 8; $0.alignment = .center
        }

        let chip = makeCategoryChip(timer.category.displayName)

        let row = UIStackView(arrangedSubviews: [appRow, UIView(), chip]).then {
            $0.axis = .horizontal; $0.alignment = .center
        }
        return row
    }

    private func makeCategoryChip(_ text: String) -> UIView {
        let label = UILabel().then {
            $0.text = text
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 12)
            $0.textColor = Palette.amber
        }
        let wrap = UIView().then {
            $0.backgroundColor = Palette.amber.withAlphaComponent(0.14)
            $0.layer.cornerRadius = 12
        }
        wrap.addSubview(label)
        label.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(5)
            $0.leading.trailing.equalToSuperview().inset(12)
        }
        return wrap
    }

    // MARK: - Hero — 펄스 링 + 벨 + 제목/상태

    private func makeHero() -> UIView {
        // 벨 배지
        let bell = UIImageView().then {
            $0.image = UIImage(
                systemName: "bell.and.waves.left.and.right.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 46, weight: .regular)
            )
            $0.tintColor = Palette.amber
            $0.contentMode = .scaleAspectFit
        }
        let bellWrap = UIView().then {
            $0.backgroundColor = Palette.amber.withAlphaComponent(0.12)
            $0.layer.cornerRadius = 58
            $0.layer.borderWidth = 1.5
            $0.layer.borderColor = Palette.amber.withAlphaComponent(0.4).cgColor
        }
        bellWrap.addSubview(bell)
        bell.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(48) }
        bellWrap.snp.makeConstraints { $0.width.height.equalTo(116) }

        // 펄스 + 벨 (같은 중심)
        let ring = UIView()
        pulse.color = Palette.amber
        ring.addSubview(pulse)
        ring.addSubview(bellWrap)
        pulse.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(240) }
        bellWrap.snp.makeConstraints { $0.center.equalToSuperview() }
        ring.snp.makeConstraints { $0.height.equalTo(240) }

        // 제목 + 상태
        let title = UILabel().then {
            $0.text = timer.label
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 26)
            $0.textColor = Palette.textPrimary
            $0.textAlignment = .center
            $0.numberOfLines = 2
        }
        let status = UILabel().then {
            $0.text = "종료 — 확인이 필요해요"
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 15)
            $0.textColor = Palette.amber
            $0.textAlignment = .center
        }
        let texts = UIStackView(arrangedSubviews: [title, status]).then {
            $0.axis = .vertical; $0.spacing = 8; $0.alignment = .center
        }

        let hero = UIStackView(arrangedSubviews: [ring, texts]).then {
            $0.axis = .vertical; $0.spacing = 36; $0.alignment = .center
        }
        return hero
    }

    // MARK: - Actions — [완료] 주 버튼

    private func makeActions() -> UIView {
        let complete = makePrimaryButton(title: "완료", icon: "checkmark", fill: DSColor.Warning._500)
        complete.addAction(UIAction { [weak self] _ in self?.onComplete?() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [complete]).then {
            $0.axis = .vertical; $0.alignment = .fill
        }
        return stack
    }

    private func makePrimaryButton(title: String, icon: String, fill: UIColor) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = fill
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.image = UIImage(
            systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        )
        config.imagePadding = 8
        config.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: DSKitFontFamily.Pretendard.semiBold.font(size: 17)
            ])
        )
        let button = UIButton(configuration: config)
        button.snp.makeConstraints { $0.height.equalTo(56) }
        return button
    }
}

// MARK: - 펄스 링 (벨 뒤 "울리는 중" 파동)

private final class PulseRingView: UIView {

    private let replicator = CAReplicatorLayer()
    private let ring = CAShapeLayer()

    var color: UIColor = .systemOrange {
        didSet { ring.strokeColor = color.cgColor }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        replicator.instanceCount = 3
        replicator.instanceDelay = 0.9
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = color.cgColor
        ring.lineWidth = 2
        ring.opacity = 0
        replicator.addSublayer(ring)
        layer.addSublayer(replicator)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        replicator.frame = bounds
        let side = min(bounds.width, bounds.height)
        let inset = CGRect(
            x: (bounds.width - side) / 2,
            y: (bounds.height - side) / 2,
            width: side,
            height: side
        )
        ring.frame = bounds
        ring.path = UIBezierPath(ovalIn: inset).cgPath
    }

    func start() {
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.55
        scale.toValue = 1.0

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.45
        opacity.toValue = 0.0

        let group = CAAnimationGroup()
        group.animations = [scale, opacity]
        group.duration = 2.7
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        ring.add(group, forKey: "pulse")
    }

    func stop() {
        ring.removeAllAnimations()
    }
}

// MARK: - Hex 색 (Km53q 다크 팔레트 — DSKit에 없는 값)
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
