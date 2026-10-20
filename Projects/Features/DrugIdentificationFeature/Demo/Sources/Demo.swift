//
//  Demo.swift
//  DrugIdentificationFeatureDemo
//
//  Created by 바견규 on 7/5/26.
//

import UIKit
import Combine

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
        container.register(PillHistoryUseCase.self) {
            DemoPillHistoryUseCase()
        }
        container.register(PillLabelUseCase.self) {
            DemoPillLabelUseCase()
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

/// 식별 기록 스텁 — 기록이 하나도 없는 계정처럼 동작하고, 저장은 늘 성공한다.
final class DemoPillHistoryUseCase: PillHistoryUseCase {
    func fetchHistories(limit: Int, cursor: String?) -> AnyPublisher<PillHistoryPageModel, Error> {
        Just(PillHistoryPageModel(items: [], nextCursor: nil)).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    func fetchLatestHistory() -> AnyPublisher<PillHistorySummaryModel?, Error> {
        Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    func fetchHistory(historyId: String) -> AnyPublisher<PillHistoryModel, Error> {
        Fail(error: PillHistoryNotFoundError()).eraseToAnyPublisher()
    }
    func saveHistory(historyId: String, pillCodes: [String]) -> AnyPublisher<Void, Error> {
        Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    func deleteHistory(historyId: String) -> AnyPublisher<Void, Error> {
        Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
}

/// 학습용 라벨 스텁 — 보낸 값을 콘솔에만 찍는다.
final class DemoPillLabelUseCase: PillLabelUseCase {
    func sendLabel(imageId: String, pillIndex: Int, label: PillLabelModel) {
        print("[label] \(imageId)/\(pillIndex) \(label.pillCode) manual=\(label.manual)")
    }
    func sendDeletedIndexes(imageId: String, deletedIndexes: [Int]) {
        print("[label] \(imageId) deleted=\(deletedIndexes)")
    }
}
