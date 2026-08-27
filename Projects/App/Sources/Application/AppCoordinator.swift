import UIKit
import Combine
import AuthFeatureInterface
import BaseFeatureDependency
import Core
import DSKit
import Domain
import TabBarFeature
import TimerFeature
import HomeFeature
import DrugIdentificationFeature

/*
 AppCoordinator

 Coordinator 패턴의 최상위 노드. "화면 전환을 누가 결정하는가"를 ViewController에서 떼어내
 별도 객체가 담당하게 하는 구조다.

   SceneDelegate → AppCoordinator → TabBarCoordinator → 각 탭의 Coordinator
        (창)          (앱 전체)         (탭 구성)          (탭 내부 화면 흐름)

 부모는 자식을 addChild로 보유하고, 자식은 자기 영역의 화면 흐름만 책임진다.
 ViewController가 다른 화면을 직접 push/present 하지 않으므로 화면 간 결합이 끊긴다.

 이 클래스가 하는 일은 세 가지다.
   1) 스플래시 → 세션 판정 → 로그인 / 동의 / 탭바 중 하나를 띄운다 (NM-410)
   2) "어느 탭으로 가라"는 앱 전역 신호를 받아 TabBarCoordinator에 전달한다
   3) 세션 만료·로그아웃 신호를 받아 로그인 화면으로 되돌린다
 */
final class AppCoordinator: BaseCoordinator {

    /// 탭 전환 요청을 위임할 대상. 아래 옵저버 클로저에서 참조해야 하므로 프로퍼티로 보유한다.
    private var tabBarCoordinator: TabBarCoordinator?

    /// 인증 흐름 코디네이터. 로그인 ↔ 로그아웃을 오갈 때 이전 것을 확실히 놓아주려고 들고 있는다.
    private var authCoordinator: CoordinatorProtocol?

    /*
     탭바가 화면에 올라온 직후 1회 실행할 작업 (NM-372).

     SceneDelegate가 콜드런치 딥링크 처리를 여기에 건다. 스플래시가 떠 있는 동안
     딥링크를 처리하면 탭 전환 신호가 버려지고(옵저버·탭바 미존재) 모달이 스플래시
     위에 뜨므로, "탭바가 준비된 시점"을 알려줄 지점이 필요하다.

     로그인 화면을 거쳐 들어온 경우에도 탭바가 뜬 뒤 여기서 처리된다 — 미로그인 상태에서
     딥링크를 열면 링크는 보관됐다가 로그인·동의를 마친 뒤에 실행된다.
     */
    var onTabBarReady: (() -> Void)?

    @Injected private var authUseCase: AuthUseCase
    @Injected private var authBuilder: AuthFeatureBuildable

    /// SceneDelegate가 window를 세팅한 직후 호출하는 진입점.
    override func start() {
        // 옵저버를 스플래시보다 먼저 건다. onTabBarReady 로 처리되는 딥링크가
        // 탭바 등장 직후 곧바로 .openTimerTab 을 쏘는데, 등록이 그보다 늦으면 삼켜진다.
        observeTabSwitching()
        observeSessionEnd()
        showSplash()
    }

    /*
     콜드런치 브랜드 스플래시 (NM-359).

     스플래시가 떠 있는 동안 세션을 복원한다 — 어차피 보여줄 시간이라 판정 지연이 사용자에게 보이지 않는다.
     표시가 끝나면(onFinish) 판정 결과에 따라 로그인·동의·탭바 중 하나로 크로스디졸브 전환한다.
     스플래시는 다음 화면을 모르고(구성은 AppCoordinator 책임), 전환 시점만 콜백으로 알린다.
     */
    private func showSplash() {
        let splash = SplashViewController()
        // 스플래시 표시(0.8초)와 세션 판정을 겹쳐 돌린다. 둘 다 끝나야 다음 화면으로 간다.
        let routeTask = Task { await authUseCase.restoreSession() }

        splash.onFinish = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                let route = await routeTask.value

                UIView.transition(
                    with: self.navigationController.view,
                    duration: 0.3,
                    options: .transitionCrossDissolve
                ) {
                    self.show(route)
                } completion: { _ in
                    // 탭바로 곧장 들어간 경우에만 여기서 딥링크를 처리한다.
                    // 로그인을 거치는 경로는 탭바가 뜨는 showTabBar() 에서 다시 흘려보낸다.
                    if route == .home { self.flushTabBarReady() }
                }
            }
        }
        navigationController.setViewControllers([splash], animated: false)
        navigationController.setNavigationBarHidden(true, animated: false)
    }

    private func show(_ route: AuthRoute) {
        switch route {
        case .login, .consent:
            showAuth(startAt: route)
        case .home:
            showTabBar()
        }
    }

    /*
     인증 흐름 (NM-410).

     로그인·동의 온보딩은 AuthFeature 가 통째로 책임진다. AppCoordinator 는 "언제 시작하고,
     끝나면 무엇을 띄우는지"만 안다. 이전 화면(스플래시·탭바)은 setViewControllers 로 교체되어
     되돌아갈 수 없다 — 로그인은 건너뛸 수 없는 단계라 뒤로 갈 곳이 없어야 맞다.
     */
    private func showAuth(startAt route: AuthRoute) {
        // 로그아웃으로 돌아온 경우 이전 탭바 트리를 놓아준다. 안 그러면 옛 코디네이터가 남아
        // 알림을 계속 받고, 새 세션의 화면과 두 벌로 겹친다.
        detachCurrentFlow()

        let coordinator = authBuilder.makeAuthCoordinator(
            navigationController: navigationController,
            startAt: route,
            onFinished: { [weak self] in self?.showTabBar() }
        )
        authCoordinator = coordinator
        addChild(coordinator)
        coordinator.start()
    }

    /// 화면을 통째로 갈아끼우기 전에 지금 트리를 떼어낸다.
    /// 로그인 ↔ 로그아웃을 오갈 때마다 코디네이터가 childCoordinators 에 쌓이는 걸 막는다.
    private func detachCurrentFlow() {
        [tabBarCoordinator as CoordinatorProtocol?, authCoordinator]
            .compactMap { $0 }
            .forEach { removeChild($0) }
        tabBarCoordinator = nil
        authCoordinator = nil
    }

    /*
     탭바 구성.

     각 탭의 Builder를 주입받는 형태 → AppCoordinator는 Home/Timer/Drug 화면의 내부 구조를 모른다.
     (Builder가 자기 모듈의 ViewController·의존성 조립을 책임짐 = 모듈 간 결합 최소화)

     addChild로 자식 Coordinator를 보유하지 않으면 즉시 해제되어 화면 흐름이 끊긴다.
     */
    private func showTabBar() {
        detachCurrentFlow()

        let tabBarCoordinator = TabBarCoordinator(
            navigationController: navigationController,
            homeBuilder: HomeFeatureBuilder(),
            timerBuilder: TimerBuilder(),
            drugBuilder: DrugIdentificationBuilder(),
            onLogout: { [weak self] in self?.confirmSignOut() },
            onDeleteAccount: { [weak self] in self?.confirmAccountDeletion() }
        )
        self.tabBarCoordinator = tabBarCoordinator
        addChild(tabBarCoordinator)
        tabBarCoordinator.start()

        flushTabBarReady()
    }

    private func flushTabBarReady() {
        let ready = onTabBarReady
        onTabBarReady = nil
        ready?()
    }

    /*
     탭 전환 진입점.
     
     탭 전환을 요청하는 쪽이 서로 멀리 떨어져 있어(SceneDelegate의 딥링크, 홈 화면의 버튼,
     알림 랜딩) 직접 참조 대신 NotificationCenter로 신호만 받는다.
     보내는 쪽은 AppCoordinator의 존재를 몰라도 되고, 받는 쪽은 여기 한 곳으로 모인다.
     
     즉 신호를 여기서 받아 처리를 해준다.
       .openTimerTab   ← 알람/딥링크 랜딩 (SceneDelegate)
       .selectTimerTab ← 홈 화면 버튼
       .selectPillTab  ← 홈 화면 버튼
       .selectHomeTab  ← 홈 복귀

     queue: .main 지정 → UI 갱신이므로 메인 스레드 보장.
     [weak self] → 클로저가 self를 강하게 잡으면 NotificationCenter가 이 객체를 놓아주지 않는다.
     */
    private func observeTabSwitching() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: .openTimerTab, object: nil, queue: .main) { [weak self] _ in
            self?.tabBarCoordinator?.switchToTimerTab()
        }
        nc.addObserver(forName: .selectTimerTab, object: nil, queue: .main) { [weak self] _ in
            self?.tabBarCoordinator?.switchToTimerTab()
        }
        nc.addObserver(forName: .selectPillTab, object: nil, queue: .main) { [weak self] _ in
            self?.tabBarCoordinator?.switchToPillTab()
        }
        nc.addObserver(forName: .selectHomeTab, object: nil, queue: .main) { [weak self] _ in
            self?.tabBarCoordinator?.switchToHomeTab()
        }
    }

    /*
     세션 종료 신호.

       .authSessionExpired ← 토큰 강제 갱신 후에도 401 (Networks 인터셉터, NM-410)
       .authDidSignOut     ← 로그아웃·탈퇴 완료 (AuthUseCase)

     둘 다 "지금 화면을 계속 보여줄 수 없다"는 같은 결론이라 한 곳으로 합류시킨다.
     이미 인증 화면이라면 아무것도 하지 않는다 — 동의 취소로 로그아웃하면 AuthCoordinator 가
     이미 로그인 화면을 들고 있어서, 여기서 또 갈아끼우면 시트가 닫히는 도중에 화면이 통째로 바뀐다.
     */
    private func observeSessionEnd() {
        let nc = NotificationCenter.default
        for name in [Notification.Name.authSessionExpired, .authDidSignOut] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.tabBarCoordinator != nil else { return }
                self.showAuth(startAt: .login)
            }
        }
    }

    // MARK: - 설정 · 계정

    /// 로그아웃 확인 (디자인: DESIGN.pen `zFi8P`).
    /// 실제 화면 전환은 `.authDidSignOut` 옵저버가 처리한다 — 로그아웃 경로가 하나로 모인다.
    private func confirmSignOut() {
        guard let host = topMostView() else { return }
        DSConfirmDialogView.present(
            on: host,
            title: "로그아웃할까요?",
            confirmTitle: "로그아웃",
            confirmed: { [weak self] in self?.authUseCase.signOut() }
        )
    }

    /// 계정 삭제 확인 (디자인: DESIGN.pen `jdS6i`). Apple 심사 필수 요건.
    private func confirmAccountDeletion() {
        guard let host = topMostView() else { return }
        DSConfirmDialogView.present(
            on: host,
            title: "계정을 삭제할까요?",
            message: "삭제하면 되돌릴 수 없어요",
            confirmTitle: "삭제",
            confirmStyle: .destructive,
            confirmed: { [weak self] in self?.deleteAccount() }
        )
    }

    private func deleteAccount() {
        Task { @MainActor in
            do {
                try await authUseCase.deleteAccount()
                // 성공하면 .authDidSignOut 이 로그인 화면으로 되돌린다.
            } catch {
                // 실패하면 로그아웃하지 않고 설정에 머문다 — 계정이 남아 있는데 삭제됐다고 안내하지 않기 위함.
                // 서버가 멱등이라 다시 눌러도 안전하다(spec: domains/auth.md §탈퇴).
                guard let host = topMostView() else { return }
                DSAlertCardView.present(
                    on: host,
                    title: "계정 삭제 실패",
                    message: "잠시 후 다시 시도해 주세요."
                )
            }
        }
    }

    /// 다이얼로그를 붙일 최상단 뷰. 모달이 떠 있어도 그 위에 뜨도록 체인을 끝까지 탄다.
    private func topMostView() -> UIView? {
        var top: UIViewController? = navigationController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top?.view
    }
}
