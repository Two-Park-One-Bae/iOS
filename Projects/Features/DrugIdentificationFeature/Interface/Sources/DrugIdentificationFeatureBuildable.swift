import UIKit
import BaseFeatureDependency

public protocol DrugIdentificationFeatureBuildable {
    func makeDrugIdentificationCoordinator(navigationController: UINavigationController) -> CoordinatorProtocol
}
