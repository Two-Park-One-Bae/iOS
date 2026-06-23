import UIKit

open class BaseCoordinator: CoordinatorProtocol {
    public var navigationController: UINavigationController
    public var childCoordinators: [CoordinatorProtocol] = []

    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    open func start() {
        fatalError("start() must be overridden")
    }
}
