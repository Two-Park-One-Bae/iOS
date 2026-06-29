import UIKit

public final class TabBarVC: UITabBarController {

    // MARK: - Properties

    let viewModel: TabBarViewModel

    // MARK: - Init

    public init(viewModel: TabBarViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
    }
}

// MARK: - UITabBarControllerDelegate

extension TabBarVC: UITabBarControllerDelegate {
    public func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard let tab = TabBarViewModel.Tab(rawValue: selectedIndex) else { return }
        viewModel.selectTab(tab)
    }
}
