import UIKit
import Combine
import SnapKit
import Then
import DSKit
import Domain

final class PhotoPreviewVC: UIViewController {

    // MARK: - Callbacks

    var onRetake: (() -> Void)?
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

    // 화면 가장자리를 밀어 뒤로 가는 것도 재촬영과 같아야 한다 — 시스템 pop 은 촬영을 다시 열지 않으므로 막고,
    // 대신 같은 제스처를 재촬영으로 받는다.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        setUI()
        setLayout()
        setActions()
    }

    // MARK: - Setup

    private func setUI() {
        view.backgroundColor = DSColor.surface
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
            $0.spacing = 10
        }

        view.addSubview(bottomStack)
        bottomStack.snp.makeConstraints {
            $0.top.equalTo(contentFrame.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-12)
        }
    }

    private func setActions() {
        // 뒤로 = 재촬영 — 확인을 묻지 않는다. 잃는 것이 사진 한 장이라 다시 찍으면 되고,
        // 경로마다 동작이 갈리면 어느 쪽으로 나갔는지에 따라 상태가 달라진다(spec 촬영 → 미리보기 §재촬영·뒤로).
        navBar.onBackTapped = { [weak self] in self?.onRetake?() }
        retakeButton.addTarget(self, action: #selector(retakeTapped), for: .touchUpInside)
        let edgeSwipe = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(edgeSwiped(_:)))
        edgeSwipe.edges = .left
        view.addGestureRecognizer(edgeSwipe)
        usePhotoButton.addTarget(self, action: #selector(usePhotoTapped), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func edgeSwiped(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended, gesture.translation(in: view).x > 60 else { return }
        onRetake?()
    }

    @objc private func retakeTapped() {
        onRetake?()
    }

    @objc private func usePhotoTapped() {
        onUsePhoto?()
    }
}
