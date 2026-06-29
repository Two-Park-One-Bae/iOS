import UIKit
import BaseFeatureDependency

public protocol TabBarFeatureBuildable {
    func makeTabBarCoordinator() -> CoordinatorProtocol
}
