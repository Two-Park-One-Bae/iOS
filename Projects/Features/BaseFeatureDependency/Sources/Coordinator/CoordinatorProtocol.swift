import UIKit

public protocol CoordinatorProtocol: AnyObject {
    var navigationController: UINavigationController { get }
    var childCoordinators: [CoordinatorProtocol] { get set }
    func start()
}

public extension CoordinatorProtocol {
    func addChild(_ coordinator: CoordinatorProtocol) {
        childCoordinators.append(coordinator)
    }

    func removeChild(_ coordinator: CoordinatorProtocol) {
        childCoordinators = childCoordinators.filter { $0 !== coordinator }
    }
}
