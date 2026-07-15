import UIKit
import SnapKit
import Then
import DSKit

final class PhotoPreviewVC: UIViewController {

    // MARK: - Callbacks

    var onRetake: (() -> Void)?
    var onUsePhoto: (() -> Void)?

    // MARK: - Properties

    private let capturedImage: UIImage

    // MARK: - UI

    // 미리보기는 하단 재촬영/이 사진 사용으로 이동하므로 뒤로 버튼 없는 타이틀바 사용.
    private let navBar = DSTitleBar(title: "미리보기").then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let photoImageView = UIImageView().then {
        $0.contentMode = .scaleAspectFill
        $0.clipsToBounds = true
    }

    private let retakeButton = SecondaryButton(title: "재촬영")
    private let usePhotoButton = PrimaryButton(title: "이 사진 사용")

    // MARK: - Init

    init(image: UIImage) {
        self.capturedImage = image
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
        photoImageView.image = capturedImage
    }

    private func setLayout() {
        view.addSubview(navBar)
        navBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
        }

        let contentFrame = UIView()
        contentFrame.clipsToBounds = true
        contentFrame.addSubview(photoImageView)

        view.addSubview(contentFrame)
        contentFrame.snp.makeConstraints {
            $0.top.equalTo(navBar.snp.bottom)
            $0.leading.trailing.equalToSuperview()
        }

        photoImageView.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(photoImageView.snp.width)
        }

        let actionBar = UIStackView(arrangedSubviews: [retakeButton, usePhotoButton]).then {
            $0.axis = .horizontal
            $0.spacing = 12
            $0.distribution = .fillEqually
        }

        view.addSubview(actionBar)
        actionBar.snp.makeConstraints {
            $0.top.equalTo(contentFrame.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-28)
        }
    }

    private func setActions() {
        retakeButton.addTarget(self, action: #selector(retakeTapped), for: .touchUpInside)
        usePhotoButton.addTarget(self, action: #selector(usePhotoTapped), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func retakeTapped() {
        onRetake?()
    }

    @objc private func usePhotoTapped() {
        onUsePhoto?()
    }
}
