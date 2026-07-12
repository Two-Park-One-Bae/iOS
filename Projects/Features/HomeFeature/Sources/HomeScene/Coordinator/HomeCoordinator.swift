import UIKit
import BaseFeatureDependency
import Core

public final class HomeCoordinator: BaseCoordinator {

    public override func start() {
        let viewModel = HomeViewModel()

        // 홈 버튼 → 홈 탭 내 push 가 아니라 탭바 전환(약물 식별=알약 탭 / 처치 타이머=타이머 탭).
        viewModel.onDrugIdentifyTapped = {
            NotificationCenter.default.post(name: .selectPillTab, object: nil)
        }
        viewModel.onTreatmentTimerTapped = {
            NotificationCenter.default.post(name: .selectTimerTab, object: nil)
        }

        let homeVC = HomeVC(viewModel: viewModel)
        navigationController.pushViewController(homeVC, animated: false)
    }
}
