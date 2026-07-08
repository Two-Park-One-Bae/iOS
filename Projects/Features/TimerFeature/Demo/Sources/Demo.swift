//
//  Demo.swift
//  TimerFeatureDemo
//
//  Created by 바견규 on 7/7/26.
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
            TimerAlarmScheduler()
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

    private var rootController: UINavigationController {
        window!.rootViewController as? UINavigationController
            ?? UINavigationController(rootViewController: UIViewController())
    }

    private lazy var coordinator = TimerCoordinator(navigationController: rootController)

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = rootController
        window?.makeKeyAndVisible()
        coordinator.start()
    }
}
