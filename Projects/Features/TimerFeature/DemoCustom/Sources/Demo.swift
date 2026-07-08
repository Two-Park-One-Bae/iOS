//
//  Demo.swift
//  TimerFeatureDemoCustom — iOS 26 미만 (커스텀)
//
//  커스텀 경로 강제: UN 단발 알림 + 반복 폴백 + 백그라운드 오디오,
//  커스텀 Live Activity(TimerLiveActivityWidget) 요약 표시.
//  17~25 시뮬레이터에서 실행하세요. (26 시뮬에서도 강제로 커스텀 경로가 동작)
//

import UIKit

import BaseFeatureDependency
import TimerFeature
import TimerFeatureInterface
import Domain
import Data
import Core

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let container = DIContainer.shared

        container.register(TimerRepositoryProtocol.self) {
            TimerRepository()
        }
        // 커스텀 경로 강제 (버전 무관)
        container.register(TimerAlarmScheduling.self) {
            CustomAlarmScheduler()
        }
        container.register(TimerUseCase.self) {
            DefaultTimerUseCase(
                repository: container.resolve(TimerRepositoryProtocol.self),
                alarmScheduler: container.resolve(TimerAlarmScheduling.self)
            )
        }
        container.register(TimerFeatureBuildable.self) {
            TimerBuilder()
        }

        // 커스텀 스택 activate — 알림 액션 처리 · 요약 Live Activity · 만료 풀스크린/사운드 · 백그라운드 생명연장
        TimerNotificationHandler.shared.activate()
        TimerLiveActivityManager.shared.activate()
        TimerRingingAlarmPresenter.shared.activate()
        BackgroundAudioKeepAlive.shared.activate()

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

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private lazy var navigationController = UINavigationController()
    private lazy var coordinator = TimerCoordinator(navigationController: navigationController)

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        coordinator.start()

        // 백그라운드 만료 복원 규칙 (SceneDelegate 데모 재현)
        DIContainer.shared.resolve(TimerUseCase.self).reload()
    }
}
