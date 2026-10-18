import UIKit
import BaseFeatureDependency
import DrugIdentificationFeatureInterface
import Domain

public final class DrugIdentificationBuilder: DrugIdentificationFeatureBuildable {

    public init() {}

    public func makeDrugIdentificationCoordinator(navigationController: UINavigationController) -> CoordinatorProtocol {
        DrugIdentificationCoordinator(navigationController: navigationController)
    }

    public func makePillHistoryDetailCoordinator(
        navigationController: UINavigationController,
        historyId: String,
        identifiedAt: Date?,
        pillCount: Int,
        onFinish: @escaping (PillHistoryDetailExit) -> Void
    ) -> CoordinatorProtocol {
        let summary = PillHistorySummaryModel(
            historyId: historyId,
            identifiedAt: identifiedAt,
            firstPillName: "",
            pillCount: pillCount
        )
        let coordinator = PillHistoryDetailCoordinator(navigationController: navigationController, summary: summary)
        coordinator.onFinish = onFinish
        return coordinator
    }
}
