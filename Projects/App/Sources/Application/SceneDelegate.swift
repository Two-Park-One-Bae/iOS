import UIKit
import Combine
import BaseFeatureDependency
import Core
import Domain
import TimerFeature

/*
 SceneDelegate

 창(Scene) 단위 델리게이트. AppDelegate가 프로세스당 1개인 것과 달리,
 창이 열릴 때마다 인스턴스가 생성되고 창이 닫히면 해제된다(iPad 멀티윈도우(같은 앱을 창 두 개로 동시에 띄우는 기능) → N개 공존 가능).
 window를 소유하므로 화면 표시가 필요한 작업은 전부 여기 책임이다.

 콜드런치 호출 순서 (콜드런치: 앱이 완전히 죽어있다가 새로 켜지는 것.)
   AppDelegate.didFinishLaunching   // SDK 초기화 (프로세스 1회)
     → scene(_:willConnectTo:)      // 창 생성 (창당 1회)
       → sceneDidBecomeActive       // 활성화 (백그라운드에서 복귀할 때마다 반복)

 "창이 존재하는가"와 "창이 활성화됐는가"는 다른 시점이다.
 willConnectTo 에서는 window가 아직 화면에 완전히 올라오지 않아 present가 안정적이지 않으므로,
 화면을 띄우는 작업(딥링크·게이트)은 sceneDidBecomeActive 로 미룬다.
 */
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    /// 이 Scene이 소유하는 창. AppDelegate가 아닌 여기 두어야 멀티윈도우에서 창별 독립이 보장된다.
    var window: UIWindow?
    /// 화면 전환 책임자. window와 수명을 같이하므로 Scene이 보유한다.
    var appCoordinator: AppCoordinator?
    /// 콜드런치 딥링크 — willConnectTo 시점엔 창이 준비 전이라 저장만 하고, 활성화 시점에 처리한다.
    private var pendingURL: URL?
    /// Remote Config 기반 차단 화면(강제 업데이트·점검). windowScene이 있어야 띄울 수 있다.
    private var appGate: AppGate?
    /// 위젯에서 온 프리셋 시작의 알람 권한 게이트 구독 보관함 (NM-360).
    private var permissionBag = Set<AnyCancellable>()
    
    /*
     ┌─────────────────────────────────┬───────────────────────────────────────┐
     │       전체 이름(selector)       │           언제 UIKit이 호출                │
     ├─────────────────────────────────┼───────────────────────────────────────┤
     │ scene(_:willConnectTo:options:) │ 창이 **연결(생성)**될 때                   │
     ├─────────────────────────────────┼───────────────────────────────────────┤
     │ scene(_:openURLContexts:)       │ 앱이 떠 있을 때 **URL(딥링크)**이           │
     │                                 │ 들어올 때                               │
     ├─────────────────────────────────┼───────────────────────────────────────┤
     │ sceneDidBecomeActive(_:)        │ 창이 활성화될 때                          │
     └─────────────────────────────────────────────────────────────────────────┘
     */

    
    /*
     scene(_:willConnectTo:options:)

     창이 생성될 때 창당 1회 호출. window를 만들어 rootViewController를 붙이는 자리.
     - connectionOptions: 이 창이 열린 이유(딥링크 URL, 알림 등). 아이콘 탭이면 비어 있다.
     - 여기서 present를 시도하지 않는다 → makeKeyAndVisible 직후라 창이 아직 활성 상태가 아니다.
     */
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // UIScene은 추상 타입 — 화면을 가진 창은 UIWindowScene 이므로 다운캐스팅이 필요하다.
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        let navigationController = UINavigationController()
        appCoordinator = AppCoordinator(navigationController: navigationController)
        appCoordinator?.start()

        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        appGate = AppGate(windowScene: windowScene)

        // 콜드런치 딥링크는 저장만 — 창이 활성화된 sceneDidBecomeActive 에서 present.
        pendingURL = connectionOptions.urlContexts.first?.url
    }

    /*
     scene(_:openURLContexts:)

     앱이 이미 떠 있는 상태(warm)에서 딥링크가 들어올 때 호출된다.
     콜드런치는 이 메서드가 아니라 willConnectTo 의 connectionOptions 로 전달되므로,
     두 경로를 모두 받아 handle(url:) 하나로 합류시킨다.
     */
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        handle(url: URLContexts.first?.url)
    }

    /*
     딥링크 라우팅 단일 진입점 (NM-302 위젯 딥링크)
       nursemate://timer/widget/howto → 설정 온보딩
       nursemate://timer/quickstart   → 빠른 시작 피커
       nursemate://timer/start?preset=<UUID> → 해당 프리셋 즉시 시작
       그 외                          → 타이머 탭으로 이동
     scheme·host가 다르면 무시 — 외부에서 임의 URL이 들어올 수 있으므로 반드시 검증한다.
     */
    private func handle(url: URL?) {
        guard let url, url.scheme == "nursemate", url.host == "timer" else { return }
        if url.path.contains("howto") {
            presentWidgetOnboarding()
        } else if url.path.contains("quickstart") {
            presentQuickStart()
        } else if url.path.contains("/start") {
            startPreset(from: url)
        } else {
            NotificationCenter.default.post(name: .openTimerTab, object: nil)
        }
    }

    /*
     설정형 위젯(iOS 26.1 미만) → 지정 프리셋을 정식 시작(Live Activity + 알림 예약).
     쿼리스트링은 외부 입력이므로 UUID 파싱·프리셋 존재 여부를 각각 확인하고, 실패 시 조용히 무시한다.
     */
    private func startPreset(from url: URL) {
        guard let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "preset" })?.value,
              let id = UUID(uuidString: raw) else { return }
        let useCase = DIContainer.shared.resolve(TimerUseCase.self)
        guard let preset = useCase.presets.value.first(where: { $0.id == id }) else { return }
        startWithAlarmGate(preset: preset, useCase: useCase)
    }

    private func presentWidgetOnboarding() {
        present(WidgetOnboardingViewController())
    }

    /*
     런처 위젯 → 전체 프리셋 목록에서 골라 즉시 시작.
     앱이 열려 있는 상태이므로 UseCase를 통해 정식 시작(알람 예약까지) 경로를 탄다.
     */
    private func presentQuickStart() {
        let useCase = DIContainer.shared.resolve(TimerUseCase.self)
        let picker = TimerQuickStartPickerViewController(presets: useCase.presets.value) { [weak self] preset in
            // 피커를 먼저 닫고(권한 시트와의 표시 충돌 방지) 알람 권한 게이트를 태운다.
            self?.topMostViewController()?.dismiss(animated: true) {
                self?.startWithAlarmGate(preset: preset, useCase: useCase)
            }
        }
        present(picker)
    }

    // MARK: - 알람 권한 게이트 (NM-360)

    /*
     위젯에서 온 프리셋 시작(딥링크 /start · 퀵스타트)의 공통 진입점.
     인앱 시작(TimerCoordinator)과 동일하게, 알람 권한을 먼저 확인하고 승인 상태에서만 실제로 시작한다.
     권한 없이 시작하면 타이머만 뜨고 알람이 울리지 않는 문제(ISS-05)를 막는다.

       authorized   → 즉시 시작
       notDetermined→ 안내 시트 → [허용] 시 시스템 권한 요청 → 승인되면 시작
       denied       → 거부 안내 시트(설정 유도), 시작하지 않음
     */
    private func startWithAlarmGate(preset: TimerPresetModel, useCase: TimerUseCase) {
        permissionBag.removeAll()
        useCase.alarmPermission
            .receive(on: DispatchQueue.main)
            .first()
            .sink { [weak self] status in
                switch status {
                case .authorized:
                    useCase.start(preset: preset)
                case .notDetermined:
                    self?.presentAlarmPrompt(preset: preset, useCase: useCase)
                case .denied:
                    self?.presentAlarmDenied()
                }
            }
            .store(in: &permissionBag)
        useCase.fetchAlarmPermission()
    }

    private func presentAlarmPrompt(preset: TimerPresetModel, useCase: TimerUseCase) {
        let vc = TimerPermissionVC(mode: .prompt)
        vc.onAllow = { [weak self, weak vc] in
            vc?.dismiss(animated: true) { self?.requestAlarmThenStart(preset: preset, useCase: useCase) }
        }
        vc.onLater = { [weak vc] in vc?.dismiss(animated: true) }
        presentAsSheet(vc)
    }

    private func requestAlarmThenStart(preset: TimerPresetModel, useCase: TimerUseCase) {
        permissionBag.removeAll()
        useCase.alarmPermission
            .receive(on: DispatchQueue.main)
            .first()
            .sink { status in
                // 시스템 다이얼로그에서 거부하면 시작하지 않는다.
                if status == .authorized { useCase.start(preset: preset) }
            }
            .store(in: &permissionBag)
        useCase.requestAlarmPermission()
    }

    private func presentAlarmDenied() {
        let vc = TimerPermissionVC(mode: .denied)
        vc.onOpenSettings = { [weak vc] in
            vc?.dismiss(animated: true) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
        vc.onBack = { [weak vc] in vc?.dismiss(animated: true) }
        presentAsSheet(vc)
    }

    /// 인앱 권한 시트(TimerCoordinator)와 동일한 바텀시트(높이 325)로 최상단 위에 띄운다.
    private func presentAsSheet(_ viewController: UIViewController, height: CGFloat = 325) {
        guard let top = topMostViewController() else { return }
        if let sheet = viewController.sheetPresentationController {
            sheet.detents = [.custom { _ in height }]
            sheet.prefersGrabberVisible = true
        }
        top.present(viewController, animated: true)
    }

    /// 현재 최상단 화면 위에 모달로 띄운다. 이미 다른 모달이 떠 있어도 가려지지 않도록 topMost를 찾는다.
    private func present(_ viewController: UIViewController) {
        guard let top = topMostViewController() else { return }
        top.present(UINavigationController(rootViewController: viewController), animated: true)
    }

    /// rootViewController에서 presentedViewController 체인을 끝까지 타고 올라간다.
    private func topMostViewController() -> UIViewController? {
        guard var top = window?.rootViewController else { return nil }
        while let presented = top.presentedViewController { top = presented }
        return top
    }

    /*
     sceneDidBecomeActive(_:)

     창이 활성화될 때마다 호출 — 콜드런치 직후는 물론 백그라운드 복귀 시에도 반복된다.
     따라서 "앱을 볼 때마다 최신이어야 하는 것"을 여기 모은다. (1회성 초기화는 AppDelegate)

     1) 타이머 재동기화 — 백그라운드에서 만료된 타이머의 RINGING 전이를 복귀 즉시 반영.
        endAt 기반이라 잔여시간 복원은 자동(NM-276 QA 규칙).
        AlarmKit App Intent가 App Group 저장소를 앱 밖에서 직접 바꿨을 수 있으므로 reload가 먼저다.
     2) Remote Config 게이팅 — 실행 중 점검이 시작될 수 있어 복귀 때마다 재평가한다.
     3) 콜드런치 딥링크 — willConnectTo 에서 보류해둔 URL을 창이 준비된 지금 처리한다.
     */
    func sceneDidBecomeActive(_ scene: UIScene) {
        let useCase = DIContainer.shared.resolve(TimerUseCase.self) // 타이머 usecase
        // App Intent(AlarmKit)가 App Group 저장소를 직접 바꿨을 수 있음 — 먼저 재동기화.
        useCase.reload() // 1. 디스크 → 메모리 다시 읽기
        useCase.refresh()  // 2. 현재 시각 기준으로 상태 재계산
        // 3. 알람 권한 캐시 갱신(NM-360) — 위젯 무음-시작 라우팅과 워치 시작 게이트가 읽는
        //    alarmAuthorized 플래그를 실제 권한으로 최신화하고 워치에 즉시 재동기화한다.
        //    이게 없으면 플래그가 미기록(nil)으로 남아 워치가 권한 없이도 시작을 허용한다.
        useCase.fetchAlarmPermission()

        // Remote Config 최신값 fetch 후 강제 업데이트/점검 게이트 갱신(포그라운드 복귀 포함).
        Task { @MainActor in
            await RemoteConfigService.shared.fetchAndActivate()
            appGate?.evaluate()
        }

        // 콜드런치 딥링크: 창이 활성화된 지금 present.
        if let url = pendingURL {
            pendingURL = nil
            handle(url: url)
        }
    }
}
