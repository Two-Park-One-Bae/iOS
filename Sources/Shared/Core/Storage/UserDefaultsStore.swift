import Foundation

// MARK: - UserDefaults Store

public final class UserDefaultsStore: @unchecked Sendable {
    public static let shared = UserDefaultsStore()
    private let defaults = UserDefaults.standard

    private init() {}

    public func value<T>(forKey key: String) -> T? {
        defaults.object(forKey: key) as? T
    }

    public func setValue<T>(_ value: T?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    public func remove(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}

// MARK: - Storage Keys

public extension UserDefaultsStore {
    enum Keys {
        public static let hasCompletedOnboarding = "hasCompletedOnboarding"
        public static let lastSyncDate = "lastSyncDate"
    }

    var hasCompletedOnboarding: Bool {
        get { value(forKey: Keys.hasCompletedOnboarding) ?? false }
        set { setValue(newValue, forKey: Keys.hasCompletedOnboarding) }
    }
}
