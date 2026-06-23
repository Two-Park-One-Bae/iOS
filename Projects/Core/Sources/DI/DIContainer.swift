import Foundation

public final class DIContainer {
    public static let shared = DIContainer()
    private var factories: [String: () -> Any] = [:]
    private init() {}

    public func register<T>(_ type: T.Type = T.self, factory: @escaping () -> T) {
        factories[String(describing: type)] = factory
    }

    public func resolve<T>(_ type: T.Type = T.self) -> T {
        let key = String(describing: type)
        guard let factory = factories[key], let value = factory() as? T else {
            fatalError("\(key) is not registered in DIContainer")
        }
        return value
    }
}
