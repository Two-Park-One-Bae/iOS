import UIKit
import BaseFeatureDependency
import Core
import Domain
import DrugIdentificationFeatureInterface
import TimerFeatureInterface

public final class HomeCoordinator: BaseCoordinator {

    @Injected var homeUseCase: HomeUseCaseProtocol
    @Injected var drugIdentificationBuilder: DrugIdentificationFeatureBuildable
    @Injected var timerBuilder: TimerFeatureBuildable

    public override func start() {
        let viewModel = HomeViewModel(useCase: homeUseCase)

        viewModel.onDrugIdentifyTapped = { [weak self] in
            self?.showDrugIdentification()
        }
        viewModel.onTreatmentTimerTapped = { [weak self] in
            self?.showTimer()
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

    // spec: 홈 상태칩 → C1 타이머 리스트
    private func showTimer() {
        let coordinator = timerBuilder.makeTimerCoordinator(navigationController: navigationController)
        addChild(coordinator)
        coordinator.start()
    }
}
