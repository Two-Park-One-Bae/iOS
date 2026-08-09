import UIKit
import BaseFeatureDependency
import DrugIdentificationFeatureInterface

public final class DrugIdentificationBuilder: DrugIdentificationFeatureBuildable {

    public init() {}

    public func makeDrugIdentificationCoordinator(navigationController: UINavigationController) -> CoordinatorProtocol {
        DrugIdentificationCoordinator(navigationController: navigationController)
    }
}
