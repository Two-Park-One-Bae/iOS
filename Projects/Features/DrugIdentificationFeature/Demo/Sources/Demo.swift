//
//  Demo.swift
//  DrugIdentificationFeatureDemo
//
//  Created by 바견규 on 7/5/26.
//

import UIKit

import BaseFeatureDependency
import DrugIdentificationFeature
import DrugIdentificationFeatureInterface
import Domain
import Core

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let container = DIContainer.shared

        container.register(PillRepositoryProtocol.self) {
            MockPillRepository()
        }
        container.register(PillUseCase.self) {
            DefaultPillUseCase(repository: container.resolve(PillRepositoryProtocol.self))
        }
        container.register(DrugIdentificationFeatureBuildable.self) {
            DrugIdentificationBuilder()
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

    private lazy var coordinator = DrugIdentificationCoordinator(navigationController: rootController)

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
        // 메인 앱에선 탭바가 알약 탭 선택 시 .pillTabSelected 를 쏴 카메라를 띄운다.
        // 데모는 탭바가 없으므로 직접 발행해 촬영 흐름을 시작한다.
        NotificationCenter.default.post(name: .pillTabSelected, object: nil)
    }
}
