import UIKit
import Combine
import BaseFeatureDependency
import Core
import Data
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
        // 콜드런치 딥링크는 탭바가 준비된 뒤에 처리한다 (NM-372). start() 보다 먼저 걸어둔다.
        appCoordinator?.onTabBarReady = { [weak self] in self?.flushPendingURL() }
        appCoordinator?.start()

        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        appGate = AppGate(windowScene: windowScene)

        // 콜드런치 딥링크는 저장만 — 탭바가 뜬 뒤(onTabBarReady) 처리한다.
        // 미로그인 상태면 로그인·동의를 마치고 탭바가 뜰 때 실행된다 (NM-410).
        pendingURL = connectionOptions.urlContexts.first?.url
    }

    /*
     scene(_:openURLContexts:)

     앱이 이미 떠 있는 상태(warm)에서 딥링크가 들어올 때 호출된다.
     콜드런치는 이 메서드가 아니라 willConnectTo 의 connectionOptions 로 전달되므로,
     두 경로를 모두 받아 handle(url:) 하나로 합류시킨다.
     */
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        // 소셜 로그인 복귀 URL(카카오톡·구글)을 먼저 본다 — 스킴이 nursemate 가 아니라
        // 아래 딥링크 라우팅에서는 어차피 걸러진다. 처리했으면 여기서 끝낸다 (NM-410).
        guard !SocialLoginSDK.handle(url: url) else { return }
        handle(url: url)
    }

    /*
     딥링크 라우팅 단일 진입점 (NM-302 위젯 딥링크)
       nursemate://timer/widget/howto → 설정 온보딩
       nursemate://timer/quickstart   → 빠른 시작 피커
       nursemate://timer/start?preset=<UUID> → 해당 프리셋 즉시 시작
       그 외                          → 타이머 탭으로 이동
     scheme·host가 다르면 무시 — 외부에서 임의 URL이 들어올 수 있으므로 반드시 검증한다.
     */
    private func handle(url: URL) {
        guard url.scheme == "nursemate", url.host == "timer" else { return }
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
        // 시작 전에 타이머 탭으로 옮긴다 (NM-372) — 방금 만든 타이머가 바로 보이고,
        // 권한 시트가 뜨는 경우에도 타이머 탭 위에 떠서 닫은 뒤 맥락이 이어진다.
        NotificationCenter.default.post(name: .openTimerTab, object: nil)
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
        // 피커를 띄우기 전에 타이머 탭으로 옮긴다 (NM-372) — 피커가 닫힐 때
        // 홈 탭이 잠깐 보였다가 전환되는 깜빡임을 없앤다.
        NotificationCenter.default.post(name: .openTimerTab, object: nil)
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
                    AppAnalytics.track(.timerStart(source: "widget", presetLabel: preset.label,
                                                   category: preset.category.displayName, durationSec: preset.duration))
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
                if status == .authorized {
                    useCase.start(preset: preset)
                    AppAnalytics.track(.timerStart(source: "widget", presetLabel: preset.label,
                                                   category: preset.category.displayName, durationSec: preset.duration))
                }
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
     콜드런치 딥링크는 여기서 처리하지 않는다 — 이 시점엔 스플래시가 떠 있다.
     탭바가 뜬 뒤 AppCoordinator.onTabBarReady 가 flushPendingURL() 을 부른다 (NM-372).
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

        // 위젯이 앱 밖(백그라운드 AppIntent, iOS 26.1+ 승인)에서 시작한 타이머 지연 집계.
        // 위젯 프로세스는 Firebase 를 링크하지 않아 timer_start 를 직접 못 보낸다(§위젯 지연로깅).
        for pending in WidgetAnalyticsQueue.drainTimerStarts() {
            AppAnalytics.track(.timerStart(
                source: "widget",
                presetLabel: pending.presetLabel,
                category: pending.category,
                durationSec: pending.durationSec
            ))
        }
        // 앱 밖 AlarmKit [완료](iOS 26.1+ stop 인텐트)로 완료된 타이머 지연 집계.
        // 26.1+ 완료는 useCase.remove 를 안 타므로 여기서만 잡힌다(중복 없음).
        for pending in WidgetAnalyticsQueue.drainTimerCompletes() {
            AppAnalytics.track(.timerComplete(
                category: pending.category,
                durationSec: pending.durationSec
            ))
        }

        // Remote Config 최신값 fetch 후 강제 업데이트/점검 게이트 갱신(포그라운드 복귀 포함).
        //
        // fetch 만으로는 부족하다 — 릴리즈는 캐시가 12시간이라 그 안에는 서버로 가지 않는다.
        // 점검 모드를 켜야 하는 순간의 사용자들은 전부 캐시를 갖고 있어 옛 값을 본다.
        // 그래서 **사용 중 실시간 청취**를 함께 켠다(Firebase 권장 구조).
        Task { @MainActor in
            await RemoteConfigService.shared.fetchAndActivate()
            appGate?.evaluate()
            RemoteConfigService.shared.startListening()
            // 리스너는 보장 장치가 아니다(측정 근거는 startPeriodicRefresh 주석 참고).
            // 포그라운드에 있는 동안은 이 폴링이 반영 상한을 60초로 묶는다.
            RemoteConfigService.shared.startPeriodicRefresh()
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // 백그라운드에서는 타이머가 어차피 안 돈다. 복귀 시 sceneDidBecomeActive 가 다시 건다.
        RemoteConfigService.shared.stopPeriodicRefresh()
    }

    /*
     콜드런치 딥링크 처리 (NM-372).

     AppCoordinator 가 탭바를 띄운 직후 호출한다. sceneDidBecomeActive 에서 처리하면
     아직 스플래시가 떠 있어서 ─ 탭 전환 신호는 옵저버·탭바가 없어 버려지고,
     피커·온보딩 모달은 탭바가 아닌 스플래시 위에 뜬다.
     */
    private func flushPendingURL() {
        guard let url = pendingURL else { return }
        pendingURL = nil
        handle(url: url)
    }
}
