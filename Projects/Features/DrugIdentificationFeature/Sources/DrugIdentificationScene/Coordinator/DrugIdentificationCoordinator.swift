import UIKit
import BaseFeatureDependency

public final class DrugIdentificationCoordinator: BaseCoordinator {

    public override func start() {
        let viewModel = DrugIdentificationViewModel()
        let vc = DrugIdentificationVC(viewModel: viewModel)
        navigationController.pushViewController(vc, animated: true)
    }
}
