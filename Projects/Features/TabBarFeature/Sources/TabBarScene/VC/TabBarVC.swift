import UIKit
import BaseFeatureDependency

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
        // 알약 탭 선택 시 약물 식별 카메라를 present (런치가 아니라 선택 시점에).
        if selectedIndex == 1 {
            NotificationCenter.default.post(name: .pillTabSelected, object: nil)
        }
    }
}
