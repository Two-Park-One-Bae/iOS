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
        FirebaseService.configure()
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
