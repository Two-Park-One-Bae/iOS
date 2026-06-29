import UIKit
import BaseFeatureDependency
import Core
import Domain

public final class HomeCoordinator: BaseCoordinator {

    @Injected var homeUseCase: HomeUseCaseProtocol

    public override func start() {
        let viewModel = HomeViewModel(useCase: homeUseCase)

        viewModel.onDrugIdentifyTapped = { [weak self] in
            // TODO: 약물 식별 화면 진입
        }
        viewModel.onTreatmentTimerTapped = { [weak self] in
            // TODO: 처치 타이머 화면 진입
        }

        let homeVC = HomeVC(viewModel: viewModel)
        navigationController.pushViewController(homeVC, animated: false)
    }
}
