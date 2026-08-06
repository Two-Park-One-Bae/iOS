import UIKit
import BaseFeatureDependency
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

 이 클래스가 하는 일은 두 가지뿐이다.
   1) 탭바를 띄운다 (앱의 첫 화면 = 탭 구조)
   2) "어느 탭으로 가라"는 앱 전역 신호를 받아 TabBarCoordinator에 전달한다
 */
final class AppCoordinator: BaseCoordinator {

    /// 탭 전환 요청을 위임할 대상. 아래 옵저버 클로저에서 참조해야 하므로 프로퍼티로 보유한다.
    private var tabBarCoordinator: TabBarCoordinator?

    /*
     탭바가 화면에 올라온 직후 1회 실행할 작업 (NM-372).

     SceneDelegate가 콜드런치 딥링크 처리를 여기에 건다. 스플래시가 떠 있는 동안
     딥링크를 처리하면 탭 전환 신호가 버려지고(옵저버·탭바 미존재) 모달이 스플래시
     위에 뜨므로, "탭바가 준비된 시점"을 알려줄 지점이 필요하다.
     */
    var onTabBarReady: (() -> Void)?

    /// SceneDelegate가 window를 세팅한 직후 호출하는 진입점.
    override func start() {
        // 옵저버를 스플래시보다 먼저 건다. onTabBarReady 로 처리되는 딥링크가
        // 탭바 등장 직후 곧바로 .openTimerTab 을 쏘는데, 등록이 그보다 늦으면 삼켜진다.
        observeTabSwitching()
        showSplash()
    }

    /*
     콜드런치 브랜드 스플래시 (NM-359).

     첫 화면으로 스플래시를 띄우고, 표시가 끝나면(onFinish) 탭바로 크로스디졸브 전환한다.
     스플래시는 다음 화면을 모르고(탭바 구성은 AppCoordinator 책임), 전환 시점만 콜백으로 알린다.
     */
    private func showSplash() {
        let splash = SplashViewController()
        splash.onFinish = { [weak self] in
            guard let self else { return }
            UIView.transition(
                with: self.navigationController.view,
                duration: 0.3,
                options: .transitionCrossDissolve
            ) {
                self.showTabBar()
            } completion: { _ in
                // 크로스디졸브가 끝나 탭바가 완전히 자리잡은 뒤 보류해둔 딥링크를 처리한다.
                // 애니메이션 블록 안에서 present 하면 전환과 겹치므로 completion 이어야 한다.
                let ready = self.onTabBarReady
                self.onTabBarReady = nil
                ready?()
            }
        }
        navigationController.setViewControllers([splash], animated: false)
        navigationController.setNavigationBarHidden(true, animated: false)
    }

    /*
     탭바 구성.

     각 탭의 Builder를 주입받는 형태 → AppCoordinator는 Home/Timer/Drug 화면의 내부 구조를 모른다.
     (Builder가 자기 모듈의 ViewController·의존성 조립을 책임짐 = 모듈 간 결합 최소화)

     addChild로 자식 Coordinator를 보유하지 않으면 즉시 해제되어 화면 흐름이 끊긴다.
     */
    private func showTabBar() {
        let tabBarCoordinator = TabBarCoordinator(
            navigationController: navigationController,
            homeBuilder: HomeFeatureBuilder(),
            timerBuilder: TimerBuilder(),
            drugBuilder: DrugIdentificationBuilder()
        )
        self.tabBarCoordinator = tabBarCoordinator
        addChild(tabBarCoordinator)
        tabBarCoordinator.start()
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
}
