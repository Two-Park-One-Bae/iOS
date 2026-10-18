import UIKit
import BaseFeatureDependency
import DrugIdentificationFeatureInterface
import Core
import Domain

// 기록 상세 흐름 (NM-552) — 기록 상세 → 세부정보.
// 알약 탭 목록과 홈 최근 식별 칩이 함께 쓴다. 상세는 들어온 화면의 스택에 push 되므로
// `뒤로` · 삭제 · 없어진 기록 모두 그 화면으로 돌아가고, 무엇 때문에 나갔는지만 `onFinish`로 알린다.
final class PillHistoryDetailCoordinator: BaseCoordinator {

    var onFinish: ((PillHistoryDetailExit) -> Void)?

    private let summary: PillHistorySummaryModel
    private weak var detailVC: PillHistoryDetailVC?

    init(navigationController: UINavigationController, summary: PillHistorySummaryModel) {
        self.summary = summary
        super.init(navigationController: navigationController)
    }

    override func start() {
        let vc = PillHistoryDetailVC(viewModel: PillHistoryDetailViewModel(summary: summary))
        detailVC = vc
        vc.onBackTapped = { [weak self] in self?.finish(.back) }
        vc.onDeleted = { [weak self] in self?.finish(.deleted) }
        vc.onNotFound = { [weak self] in self?.finish(.notFound) }
        vc.onSelectDetail = { [weak self] pillCode, licenseStatus in
            self?.showPillDetail(pillCode: pillCode, licenseStatus: licenseStatus)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    private func showPillDetail(pillCode: String, licenseStatus: LicenseStatus) {
        let viewModel = PillDetailViewModel(pillCode: pillCode, licenseStatus: licenseStatus)
        let vc = PillDetailVC(viewModel: viewModel)
        vc.onBackTapped = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    /// 상세(와 그 위 세부정보)를 걷어내고 들어온 화면으로 돌아간다.
    private func finish(_ exit: PillHistoryDetailExit) {
        if let detailVC, let index = navigationController.viewControllers.firstIndex(of: detailVC), index > 0 {
            navigationController.popToViewController(navigationController.viewControllers[index - 1], animated: true)
        }
        onFinish?(exit)
    }
}
