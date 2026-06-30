import UIKit
import Combine
import DSKit

public final class DrugIdentificationVC: UIViewController {

    private let viewModel: DrugIdentificationViewModel
    private var cancelBag = Set<AnyCancellable>()

    public init(viewModel: DrugIdentificationViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
        bind()
    }

    private func setUI() {
        view.backgroundColor = DSColor.bgApp
        navigationItem.title = "약물 식별"
    }

    private func bind() {
        let input = DrugIdentificationViewModel.Input(
            viewDidLoad: Just(()).eraseToAnyPublisher()
        )
        _ = viewModel.transform(input: input)
    }
}
