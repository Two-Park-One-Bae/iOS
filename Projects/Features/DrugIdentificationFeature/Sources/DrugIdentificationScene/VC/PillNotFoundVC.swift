import UIKit
import SnapKit
import Then
import DSKit

final class PillNotFoundVC: UIViewController {

    // MARK: - Callbacks

    var onRetake: (() -> Void)?
    var onSelectFromGallery: (() -> Void)?
    /// 뒤로 = 홈 복귀. 이 화면들엔 잃을 작업이 없어 확인 팝업 없이 바로 나간다.
    var onBackTapped: (() -> Void)?

    // MARK: - Properties

    private let image: UIImage

    // MARK: - UI

    private let navBar = DSNavBar(title: "인식 결과").then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let photoCard = UIView().then {
        $0.backgroundColor = DSColor.Neutral._0
        $0.layer.cornerRadius = 20
        $0.layer.shadowColor = UIColor.black.cgColor
        $0.layer.shadowOpacity = 0.12
        $0.layer.shadowOffset = CGSize(width: 0, height: 4)
        $0.layer.shadowRadius = 16
        $0.layer.masksToBounds = false
    }

    private let photoContainer = UIView().then {
        $0.layer.cornerRadius = 14
        $0.clipsToBounds = true
    }

    private let photoImageView = UIImageView().then {
        $0.contentMode = .scaleAspectFill
        $0.clipsToBounds = true
    }

    private let dimOverlay = UIView().then {
        $0.backgroundColor = DSColor.Neutral._900.withAlphaComponent(0.55)
    }

    private let iconView = UIImageView().then {
        $0.image = DSIcon.searchX.uiImage
        $0.tintColor = DSColor.Neutral._0
        $0.contentMode = .scaleAspectFit
    }

    private let titleLabel = UILabel().then {
        $0.text = "알약을 찾지 못했어요"
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 20)
        $0.textColor = DSColor.textPrimary
        $0.textAlignment = .center
    }

    private let descLabel = UILabel().then {
        $0.text = "알약이 잘 보이도록 다시 촬영하거나\n갤러리에서 다시 선택해 주세요"
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 15)
        $0.textColor = DSColor.textSecondary
        $0.textAlignment = .center
        $0.numberOfLines = 0
    }

    private let retakeButton = PrimaryButton(title: "재촬영")
    private let galleryButton = SecondaryButton(title: "갤러리에서 선택")

    // MARK: - Init

    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        setUI()
        setLayout()
        setActions()
    }

    // MARK: - Setup

    private func setUI() {
        view.backgroundColor = DSColor.bgApp
        photoImageView.image = image
        navBar.onBackTapped = { [weak self] in self?.onBackTapped?() }
    }

    private func setLayout() {
        view.addSubview(navBar)
        navBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
        }

        photoCard.addSubview(photoContainer)
        photoContainer.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(8)
            $0.size.equalTo(300)
        }

        photoContainer.addSubview(photoImageView)
        photoImageView.snp.makeConstraints { $0.edges.equalToSuperview() }

        photoContainer.addSubview(dimOverlay)
        dimOverlay.snp.makeConstraints { $0.edges.equalToSuperview() }

        photoContainer.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(48)
        }

        let textStack = UIStackView(arrangedSubviews: [titleLabel, descLabel]).then {
            $0.axis = .vertical
            $0.spacing = 8
            $0.alignment = .center
        }

        let centerStack = UIStackView(arrangedSubviews: [photoCard, textStack]).then {
            $0.axis = .vertical
            $0.spacing = 24
            $0.alignment = .center
        }

        view.addSubview(centerStack)
        centerStack.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(40)
        }

        let footerStack = UIStackView(arrangedSubviews: [retakeButton, galleryButton]).then {
            $0.axis = .vertical
            $0.spacing = 10
            $0.alignment = .fill
        }

        view.addSubview(footerStack)
        footerStack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-28)
        }
    }

    private func setActions() {
        retakeButton.addTarget(self, action: #selector(retakeTapped), for: .touchUpInside)
        galleryButton.addTarget(self, action: #selector(galleryTapped), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func retakeTapped() {
        onRetake?()
    }

    @objc private func galleryTapped() {
        onSelectFromGallery?()
    }
}
