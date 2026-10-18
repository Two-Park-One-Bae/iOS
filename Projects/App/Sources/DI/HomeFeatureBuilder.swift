import UIKit
import HomeFeatureInterface
import HomeFeature
import BaseFeatureDependency
import DrugIdentificationFeatureInterface

final class HomeFeatureBuilder: HomeFeatureBuildable {
    /// 홈 최근 식별 칩 → 기록 상세 (NM-552)
    private let drugBuilder: DrugIdentificationFeatureBuildable

    init(drugBuilder: DrugIdentificationFeatureBuildable) {
        self.drugBuilder = drugBuilder
    }

    func makeHomeCoordinator(navigationController: UINavigationController) -> CoordinatorProtocol {
        let coordinator = HomeCoordinator(navigationController: navigationController, drugBuilder: drugBuilder)
        return coordinator
    }
}
