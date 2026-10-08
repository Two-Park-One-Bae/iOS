import UIKit
import BaseFeatureDependency
import Domain

public protocol AuthFeatureBuildable {
    /// 인증 흐름(로그인 → 동의 온보딩)의 코디네이터.
    ///
    /// - Parameters:
    ///   - startAt: 세션 복원 결과로 정해진 시작 지점. `.home` 은 이 흐름의 값이 아니라 넘기지 않는다.
    ///   - onFinished: 동의까지 충족돼 홈으로 갈 수 있는 상태가 됐다.
    func makeAuthCoordinator(
        navigationController: UINavigationController,
        startAt route: AuthRoute,
        onFinished: @escaping () -> Void
    ) -> CoordinatorProtocol

    /// 설정 > 약관 및 동의 — 약관 확인과 선택 동의의 철회·재동의 (NM-548). 설정 탭 스택에 push 한다.
    func makeConsentSettingsViewController() -> UIViewController
}
