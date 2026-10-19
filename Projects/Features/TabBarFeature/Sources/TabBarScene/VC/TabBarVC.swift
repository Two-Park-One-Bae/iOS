import UIKit
import BaseFeatureDependency
import DSKit

// 탭 바는 V2.1.0 디자인의 떠 있는 유리 캡슐(`DSTabBar`)을 쓴다 — 시스템 탭 바는 숨긴다.
// 탭 전환 · 각 탭의 내비게이션 스택은 UITabBarController 가 그대로 맡고, DSTabBar 는 그리기와 누름만 한다.
public final class TabBarVC: UITabBarController {

    // MARK: - Properties

    let viewModel: TabBarViewModel

    private var customTabBar: DSTabBar?

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
        hideSystemTabBar()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hideSystemTabBar()
        updateContentInsets()
    }

    // 홈 버튼 · 딥링크처럼 코드로 탭을 바꿔도 선택 표시가 따라오게 한다.
    public override var selectedIndex: Int {
        didSet { customTabBar?.selectedIndex = selectedIndex }
    }

    public override var selectedViewController: UIViewController? {
        didSet { customTabBar?.selectedIndex = selectedIndex }
    }

    // MARK: - Custom Tab Bar

    /// 탭 구성(viewControllers)을 넣은 뒤 부른다.
    func installTabBar(items: [DSTabBar.Item]) {
        customTabBar?.removeFromSuperview()
        let bar = DSTabBar(items: items)
        bar.selectedIndex = selectedIndex
        bar.onSelect = { [weak self] index in self?.selectFromTabBar(index) }
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)

        // 디자인: 좌우 20, 화면 아래 22 (홈 인디케이터 위 12). 인디케이터가 없는 기기는 아래 12.
        let aboveIndicator = bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 12)
        aboveIndicator.priority = .defaultHigh
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            aboveIndicator,
            bar.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -12)
        ])
        customTabBar = bar
    }

    /// 시스템 탭 바를 누른 것과 같게 처리한다 — 선택 중인 탭을 다시 누르면 처음 화면으로 돌아간다.
    private func selectFromTabBar(_ index: Int) {
        guard let controllers = viewControllers, controllers.indices.contains(index) else { return }
        let target = controllers[index]
        if index == selectedIndex {
            (target as? UINavigationController)?.popToRootViewController(animated: true)
            return
        }
        selectedIndex = index
        delegate?.tabBarController?(self, didSelect: target)
    }

    private func hideSystemTabBar() {
        if #available(iOS 18.0, *) {
            if !isTabBarHidden { setTabBarHidden(true, animated: false) }
        } else {
            tabBar.isHidden = true
        }
    }

    /// 탭 화면의 아래 안전 영역을 떠 있는 탭 바 위까지 늘린다 — 목록 끝 · 띄운 버튼이 가려지지 않게.
    private func updateContentInsets() {
        guard let bar = customTabBar else { return }
        let covered = view.bounds.maxY - bar.frame.minY - view.safeAreaInsets.bottom
        let inset = max(0, covered)
        for controller in viewControllers ?? [] where controller.additionalSafeAreaInsets.bottom != inset {
            controller.additionalSafeAreaInsets.bottom = inset
        }
    }
}

// MARK: - UITabBarControllerDelegate

extension TabBarVC: UITabBarControllerDelegate {
    public func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard let tab = TabBarViewModel.Tab(rawValue: selectedIndex) else { return }
        viewModel.selectTab(tab)
        // 알약 탭이 선택되면 잔여 횟수 갱신 · 모델 예열 (알약 탭 루트는 기록 목록 — NM-552).
        if selectedIndex == 1 {
            NotificationCenter.default.post(name: .pillTabSelected, object: nil)
        }
    }
}
