import UIKit
import BaseFeatureDependency
import DrugIdentificationFeatureInterface
import Core
import DSKit
import Domain

public final class HomeCoordinator: BaseCoordinator {

    /// 최근 식별 칩 → 기록 상세를 홈 스택에 띄우는 데 쓴다 (NM-552). 없으면 칩을 눌러도 아무 일도 없다.
    private let drugBuilder: DrugIdentificationFeatureBuildable?
    private weak var homeVC: HomeVC?

    public init(navigationController: UINavigationController, drugBuilder: DrugIdentificationFeatureBuildable? = nil) {
        self.drugBuilder = drugBuilder
        super.init(navigationController: navigationController)
    }

    public override func start() {
        let viewModel = HomeViewModel()

        // 홈 버튼 → 홈 탭 내 push 가 아니라 탭바 전환(약물 식별=알약 탭에서 곧장 촬영 / 처치 타이머=타이머 탭).
        viewModel.onDrugIdentifyTapped = {
            NotificationCenter.default.post(name: .selectPillTab, object: nil)
            NotificationCenter.default.post(name: .startPillCapture, object: nil)
        }
        viewModel.onTreatmentTimerTapped = {
            NotificationCenter.default.post(name: .selectTimerTab, object: nil)
        }
        // 기록 상세는 홈 스택에 push 한다 — `뒤로`가 홈이다 (spec: 상세에서 `뒤로`는 홈).
        viewModel.onRecentHistoryTapped = { [weak self] summary in
            self?.showHistoryDetail(summary)
        }

        let homeVC = HomeVC(viewModel: viewModel)
        self.homeVC = homeVC
        navigationController.pushViewController(homeVC, animated: false)
    }

    private func showHistoryDetail(_ summary: PillHistorySummaryModel) {
        guard let drugBuilder else { return }
        AppAnalytics.track(.buttonTap(target: "recent_history", screen: "home"))
        var coordinator: CoordinatorProtocol?
        coordinator = drugBuilder.makePillHistoryDetailCoordinator(
            navigationController: navigationController,
            historyId: summary.historyId,
            identifiedAt: summary.identifiedAt,
            pillCount: summary.pillCount
        ) { [weak self] exit in
            guard let self else { return }
            if let coordinator { self.removeChild(coordinator) }
            // 칩은 홈이 보일 때 다시 받으므로 지웠거나 없어진 기록은 돌아오면 빠진다.
            if exit == .notFound {
                self.homeVC?.showToast("기록을 찾을 수 없어요")
            }
        }
        guard let coordinator else { return }
        addChild(coordinator)
        coordinator.start()
    }
}
