import UIKit
import BaseFeatureDependency
import Core
import Domain
import DrugIdentificationFeatureInterface

public final class HomeCoordinator: BaseCoordinator {

    @Injected var homeUseCase: HomeUseCaseProtocol
    @Injected var drugIdentificationBuilder: DrugIdentificationFeatureBuildable

    public override func start() {
        let viewModel = HomeViewModel(useCase: homeUseCase)

        viewModel.onDrugIdentifyTapped = { [weak self] in
            self?.showDrugIdentification()
        }
        viewModel.onTreatmentTimerTapped = { [weak self] in
            // TODO: 처치 타이머 화면 진입
        }

        let homeVC = HomeVC(viewModel: viewModel)
        navigationController.pushViewController(homeVC, animated: false)
    }

    private func showDrugIdentification() {
        let coordinator = drugIdentificationBuilder.makeDrugIdentificationCoordinator(
            navigationController: navigationController
        )
        addChild(coordinator)
        coordinator.start()
    }
}
