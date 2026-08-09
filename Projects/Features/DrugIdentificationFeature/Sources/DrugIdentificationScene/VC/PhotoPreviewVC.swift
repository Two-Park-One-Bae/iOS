import UIKit
import Combine
import SnapKit
import Then
import DSKit
import Domain

final class PhotoPreviewVC: UIViewController {

    // MARK: - Callbacks

    var onRetake: (() -> Void)?
    /// 촬영 중단 → 홈 복귀. 뒤로 탭 시 확인 팝업을 거쳐 호출된다.
    var onExitToHome: (() -> Void)?
    var onUsePhoto: (() -> Void)?

    // MARK: - Properties

    private let capturedImage: UIImage

    // MARK: - UI

    // 뒤로는 이전 화면이 아니라 '중단하고 홈으로'. 이전 단계로 돌아가는 건 하단 재촬영이 담당한다.
    private let navBar = DSNavBar(title: "미리보기").then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let photoImageView = UIImageView().then {
        $0.contentMode = .scaleAspectFill
        $0.clipsToBounds = true
    }

    private let retakeButton = SecondaryButton(title: "재촬영")
    private let usePhotoButton = PrimaryButton(title: "이 사진 사용")

    // '이 사진 사용' 위에 놓이는 남은 횟수. 값을 모르면 숨긴다.
    private let usageLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.medium.font(size: 12)
        $0.textColor = DSColor.textTertiary
        $0.textAlignment = .center
        $0.isHidden = true
    }

    private var cancelBag = Set<AnyCancellable>()

    // MARK: - Init

    init(image: UIImage) {
        self.capturedImage = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 남은 횟수 바인딩 — 0회일 때만 경고색으로 표시한다 (NM-323).
    func bindUsage(_ usage: AnyPublisher<PillUsageModel?, Never>) {
        usage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] usage in
                guard let self else { return }
                guard let usage else {
                    self.usageLabel.isHidden = true
                    return
                }
                self.usageLabel.isHidden = false
                self.usageLabel.text = usage.remainingText
                self.usageLabel.textColor = usage.isExhausted
                    ? DSColor.Error._600
                    : DSColor.textTertiary
            }
            .store(in: &cancelBag)
    }

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

        // 남은 횟수는 '이 사진 사용' 위에 놓는다. 숨김 상태면 스택에서 자동으로 접힌다.
        let bottomStack = UIStackView(arrangedSubviews: [usageLabel, actionBar]).then {
            $0.axis = .vertical
            $0.spacing = 8
        }

        view.addSubview(bottomStack)
        bottomStack.snp.makeConstraints {
            $0.top.equalTo(contentFrame.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-28)
        }
    }

    private func setActions() {
        navBar.onBackTapped = { [weak self] in
            self?.presentExitConfirm(title: "지금 나가면 촬영한 사진이 사라져요") {
                self?.onExitToHome?()
            }
        }
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
