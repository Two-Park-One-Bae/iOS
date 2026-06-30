import UIKit
import SnapKit
import Then
import DSKit

public final class PermissionDeniedVC: UIViewController {

    // MARK: - Callbacks

    var onOpenSettings: (() -> Void)?
    var onSelectFromGallery: (() -> Void)?
    var onBackTapped: (() -> Void)?

    // MARK: - UI

    private let navBar = DSNavBar(title: "").then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let iconBackground = UIView().then {
        $0.backgroundColor = DSColor.Primary._50
        $0.layer.cornerRadius = 48
    }

    private let iconView = UIImageView().then {
        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)
        $0.image = UIImage(systemName: "camera.slash", withConfiguration: config)
        $0.tintColor = DSColor.Primary._500
        $0.contentMode = .scaleAspectFit
    }

    private let titleLabel = UILabel().then {
        $0.text = "카메라 접근이 필요해요"
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 20)
        $0.textColor = DSColor.textPrimary
        $0.textAlignment = .center
    }

    private let descLabel = UILabel().then {
        $0.text = "알약을 촬영하려면 카메라 권한을 허용해 주세요"
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 15)
        $0.textColor = DSColor.textSecondary
        $0.textAlignment = .center
        $0.numberOfLines = 0
    }

    private let settingsButton = PrimaryButton(title: "설정으로 이동")
    private let galleryButton = TextButton(title: "갤러리에서 선택하기")

    // MARK: - Init

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        setUI()
        setLayout()
        setActions()
    }

    // MARK: - Setup

    private func setUI() {
        view.backgroundColor = DSColor.bgApp
        navBar.onBackTapped = { [weak self] in self?.onBackTapped?() }
    }

    private func setLayout() {
        view.addSubview(navBar)
        navBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
        }

        iconBackground.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(42)
        }

        let textStack = UIStackView(arrangedSubviews: [titleLabel, descLabel]).then {
            $0.axis = .vertical
            $0.spacing = 8
            $0.alignment = .center
        }

        let centerStack = UIStackView(arrangedSubviews: [iconBackground, textStack]).then {
            $0.axis = .vertical
            $0.spacing = 20
            $0.alignment = .center
        }

        view.addSubview(centerStack)
        iconBackground.snp.makeConstraints { $0.size.equalTo(96) }
        centerStack.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(40)
        }

        let footerStack = UIStackView(arrangedSubviews: [settingsButton, galleryButton]).then {
            $0.axis = .vertical
            $0.spacing = 4
            $0.alignment = .center
        }

        view.addSubview(footerStack)
        settingsButton.snp.makeConstraints { $0.leading.trailing.equalToSuperview() }
        footerStack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-28)
        }
    }

    private func setActions() {
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        galleryButton.addTarget(self, action: #selector(galleryTapped), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func settingsTapped() {
        onOpenSettings?()
    }

    @objc private func galleryTapped() {
        onSelectFromGallery?()
    }
}
