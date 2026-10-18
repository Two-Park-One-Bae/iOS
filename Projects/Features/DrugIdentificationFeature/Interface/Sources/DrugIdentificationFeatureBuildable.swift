import UIKit
import BaseFeatureDependency

public protocol DrugIdentificationFeatureBuildable {
    func makeDrugIdentificationCoordinator(navigationController: UINavigationController) -> CoordinatorProtocol

    /// 식별 기록 상세 (NM-552) — 홈 최근 식별 칩처럼 알약 탭 밖에서 여는 경로.
    /// 상세는 넘겨받은 내비게이션 스택에 push 되므로 `뒤로`는 그 화면으로 돌아간다.
    func makePillHistoryDetailCoordinator(
        navigationController: UINavigationController,
        historyId: String,
        identifiedAt: Date?,
        pillCount: Int,
        onFinish: @escaping (PillHistoryDetailExit) -> Void
    ) -> CoordinatorProtocol
}

/// 기록 상세에서 나간 이유 — 들어온 화면이 목록을 다시 받거나 알림을 띄우는 데 쓴다.
public enum PillHistoryDetailExit {
    case back
    case deleted
    /// 다른 기기에서 지웠거나 100건 상한으로 지워진 기록 — `기록을 찾을 수 없어요`
    case notFound
}
