//
//  Demo.swift
//  TimerFeatureDemoAlarmKit — iOS 26+ (AlarmKit)
//
//  AlarmKit 경로 강제: 시스템 알람 + AlarmKit 카운트다운 Live Activity.
//  26.1+ 시뮬레이터에서 실행하세요. (미만에서 실행하면 자동으로 커스텀 폴백)
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
        container.register(TimerAlarmScheduling.self) {
            if #available(iOS 26.1, *) {
                return AlarmKitAlarmScheduler()
            }
            return UnavailableAlarmScheduler()
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

        // AlarmKit(26.1+)은 시스템이 알람·카운트다운 LA를 단독 관리 — 커스텀 스택 activate 안 함.

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
    }
}
