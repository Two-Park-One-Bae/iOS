import UIKit
import BaseFeatureDependency
import Core
import Domain

public final class HomeCoordinator: BaseCoordinator {
    @Injected var homeUseCase: HomeUseCaseProtocol

    public override func start() {
        let viewModel = HomeViewModel(useCase: homeUseCase)
        let homeVC = HomeVC(viewModel: viewModel)
        homeVC.coordinator = self
        navigationController.pushViewController(homeVC, animated: false)
    }

    func pushDetail(id: Int) {
        // TODO: Navigate to detail screen
    }
}
