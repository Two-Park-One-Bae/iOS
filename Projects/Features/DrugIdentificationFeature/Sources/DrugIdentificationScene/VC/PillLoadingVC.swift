import UIKit
import Combine
import SnapKit
import Then
import DSKit

// ④ 로딩 (식별 중) — 촬영 사진 + 스피너. ViewModel 파이프라인이 여기서 실행된다.
final class PillLoadingVC: UIViewController {

    // MARK: - Callbacks

    var onSuccess: (([IdentifiedPill], UIImage) -> Void)?
    var onEmpty: (() -> Void)?
    var onFailure: ((String) -> Void)?
    var onBackTapped: (() -> Void)?

    // MARK: - Properties

    private let viewModel: DrugIdentificationViewModel
    private let capturedImage: UIImage
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private var cancelBag = Set<AnyCancellable>()

    // MARK: - UI

    private let navBar = DSNavBar(title: "").then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let photoCard = PhotoCardView()

    private let spinner = DSLoading(text: "식별 중...")

    private let titleLabel = UILabel().then {
        $0.text = "알약을 식별하고 있어요"
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 17)
        $0.textColor = DSColor.textPrimary
        $0.textAlignment = .center
    }

    private let subtitleLabel = UILabel().then {
        $0.text = "잠시만 기다려 주세요"
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
        $0.textColor = DSColor.textTertiary
        $0.textAlignment = .center
    }

    // MARK: - Init

    init(image: UIImage, viewModel: DrugIdentificationViewModel) {
        self.capturedImage = image
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        setUI()
        setLayout()
        bind()
        viewDidLoadSubject.send(())
    }

    // MARK: - Setup

    private func setUI() {
        view.backgroundColor = DSColor.bgApp
        photoCard.setImage(capturedImage)
        navBar.onBackTapped = { [weak self] in self?.onBackTapped?() }
    }

    private func setLayout() {
        [navBar, photoCard, spinner, titleLabel, subtitleLabel].forEach(view.addSubview)

        navBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
        }

        photoCard.snp.makeConstraints {
            $0.top.equalTo(navBar.snp.bottom).offset(12)
            $0.centerX.equalToSuperview()
        }

        spinner.snp.makeConstraints {
            $0.top.equalTo(photoCard.snp.bottom).offset(48)
            $0.centerX.equalToSuperview()
        }

        titleLabel.snp.makeConstraints {
            $0.top.equalTo(spinner.snp.bottom).offset(4)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        subtitleLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(6)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
    }

    private func bind() {
        let input = DrugIdentificationViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher()
        )
        let output = viewModel.transform(input: input)

        output.state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .loading:
                    break
                case let .success(pills, image):
                    self.onSuccess?(pills, image)
                case .empty:
                    self.onEmpty?()
                case let .failure(message):
                    self.onFailure?(message)
                }
            }
            .store(in: &cancelBag)
    }
}
