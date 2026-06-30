import UIKit
import Combine
import SnapKit
import Then
import DSKit

public final class DrugIdentificationVC: UIViewController {

    // MARK: - Properties

    private let viewModel: DrugIdentificationViewModel
    private var cancelBag = Set<AnyCancellable>()
    public var capturedImage: UIImage?

    // MARK: - UI

    private let navBar = DSNavBar(title: "약물 식별").then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let imageView = UIImageView().then {
        $0.contentMode = .scaleAspectFit
        $0.clipsToBounds = true
        $0.layer.cornerRadius = DSRadius.md
        $0.backgroundColor = DSColor.Neutral._100
    }

    // MARK: - Init

    public init(viewModel: DrugIdentificationViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        setUI()
        setLayout()
        bind()
    }

    // MARK: - Setup

    private func setUI() {
        view.backgroundColor = DSColor.bgApp
        imageView.image = capturedImage
        navBar.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }

    private func setLayout() {
        view.addSubview(navBar)
        view.addSubview(imageView)

        navBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
        }

        imageView.snp.makeConstraints {
            $0.top.equalTo(navBar.snp.bottom).offset(20)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(imageView.snp.width)
        }
    }

    private func bind() {
        let input = DrugIdentificationViewModel.Input(
            viewDidLoad: Just(()).eraseToAnyPublisher()
        )
        _ = viewModel.transform(input: input)
    }
}
