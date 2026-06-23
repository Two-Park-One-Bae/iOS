import Foundation

@propertyWrapper
public struct Injected<T> {
    public var wrappedValue: T

    public init() {
        self.wrappedValue = DIContainer.shared.resolve(T.self)
    }
}
