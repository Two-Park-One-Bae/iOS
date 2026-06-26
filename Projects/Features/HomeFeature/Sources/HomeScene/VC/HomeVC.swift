import UIKit
import Combine
import SnapKit
import Then
import DSKit
import Domain

public final class HomeVC: UIViewController {

    // MARK: - Properties
    private let viewModel: HomeViewModel
    private var cancelBag = Set<AnyCancellable>()
    weak var coordinator: HomeCoordinator?

    private let itemSelectedSubject = PassthroughSubject<Int, Never>()
    private var items: [HomeEntity] = []

    // MARK: - UI
    private lazy var tableView = UITableView(frame: .zero, style: .plain).then {
        $0.register(HomeCell.self, forCellReuseIdentifier: HomeCell.identifier)
        $0.separatorStyle = .none
        $0.backgroundColor = DSColor.bgApp
        $0.dataSource = self
        $0.delegate = self
    }

    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    // MARK: - Init
    public init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
        setLayout()
        bind()
    }

    // MARK: - Binding
    private func bind() {
        let input = HomeViewModel.Input(
            viewDidLoad: Just(()).eraseToAnyPublisher(),
            itemSelected: itemSelectedSubject.eraseToAnyPublisher()
        )
        let output = viewModel.transform(input: input)

        output.items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.items = items
                self?.tableView.reloadData()
            }
            .store(in: &cancelBag)

        output.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                isLoading ? self?.loadingIndicator.startAnimating()
                          : self?.loadingIndicator.stopAnimating()
            }
            .store(in: &cancelBag)
    }

    // MARK: - Setup
    private func setUI() {
        view.backgroundColor = DSColor.bgApp
        navigationItem.title = "홈"
    }

    private func setLayout() {
        view.addSubview(tableView)
        view.addSubview(loadingIndicator)

        tableView.snp.makeConstraints {
            $0.edges.equalTo(view.safeAreaLayoutGuide)
        }
        loadingIndicator.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
    }
}

// MARK: - UITableViewDataSource
extension HomeVC: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: HomeCell.identifier,
            for: indexPath
        ) as? HomeCell else { return UITableViewCell() }
        cell.configure(with: items[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate
extension HomeVC: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        itemSelectedSubject.send(indexPath.row)
        coordinator?.pushDetail(id: items[indexPath.row].id)
    }
}
