import UIKit
import Core
import TimerFeature

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        RegisterDependencies.register()
        // App Check 팩토리는 반드시 FirebaseApp.configure() 이전에 설정해야 적용된다.
        AppCheckService.configure()
        FirebaseService.configure()
        // 분석 유저 식별자 = 서버가 기기 식별에 쓰는 Keychain UUID(X-Device-Id, NM-322).
        // Amplitude·Crashlytics를 같은 device_id로 묶어 서버 로그와 교차 대조 가능하게 한다.
        // Keychain 불가로 nil이면 설정을 건너뛴다(익명 유지). Crashlytics는 configure 이후에 지정.
        if let deviceID = DeviceIdentifier.current {
            AmplitudeService.setUserID(deviceID)
            FirebaseService.setUserID(deviceID)
        }
        // Remote Config fetch + 게이팅(강제 업데이트·점검)은 window 를 소유한 SceneDelegate 가
        // sceneDidBecomeActive 에서 담당한다(포그라운드 복귀 시에도 최신값 반영).
        ClarityService.configure()
        AmplitudeService.track(AppLaunchEvent())
        if #available(iOS 26.1, *) {
            // iOS 26: AlarmKit이 시스템 알람 + 카운트다운 위젯을 단독 담당.
            // (커스텀 LA / 포그라운드 풀스크린 / UN 알림 / 백그라운드 오디오 모두 비활성)
        } else {
            TimerNotificationHandler.shared.activate()
            TimerLiveActivityManager.shared.activate()
            TimerRingingAlarmPresenter.shared.activate()
            BackgroundAudioKeepAlive.shared.activate()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
