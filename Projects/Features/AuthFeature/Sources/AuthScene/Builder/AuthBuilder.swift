import UIKit
import AuthFeatureInterface
import BaseFeatureDependency
import Domain

public final class AuthBuilder: AuthFeatureBuildable {

    public init() {}

    public func makeAuthCoordinator(
        navigationController: UINavigationController,
        startAt route: AuthRoute,
        onFinished: @escaping () -> Void
    ) -> CoordinatorProtocol {
        AuthCoordinator(navigationController: navigationController, startAt: route, onFinished: onFinished)
    }
}
