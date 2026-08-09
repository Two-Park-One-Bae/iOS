import Foundation

public final class DIContainer {
    public static let shared = DIContainer()
    private var factories: [String: () -> Any] = [:]
    private var instances: [String: Any] = [:]
    private let lock = NSRecursiveLock()
    private init() {}

    public func register<T>(_ type: T.Type = T.self, factory: @escaping () -> T) {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }
        factories[key] = factory
        // 재등록 시 기존 캐시 무효화 — 이후 resolve가 새 팩토리로 다시 생성한다.
        instances.removeValue(forKey: key)
    }

    public func resolve<T>(_ type: T.Type = T.self) -> T {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }

        // 이미 생성된 인스턴스가 있으면 재사용 (싱글톤) — 같은 타입을 여러 곳에서
        // resolve 해도 항상 동일 인스턴스가 돌아가 상태가 공유된다.
        // (UseCase·Repository 등 상태를 가지는 의존성이 resolve 마다 새로 만들어지면
        //  구독·상태가 끊어지는 치명적 버그가 생긴다 — TimerLiveActivity 참고.)
        if let cached = instances[key] as? T {
            return cached
        }

        guard let factory = factories[key], let value = factory() as? T else {
            fatalError("\(key) is not registered in DIContainer")
        }
        instances[key] = value
        return value
    }
}
