import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics

public enum FirebaseService {
    public static func configure() {
        FirebaseApp.configure()
    }

    /// Firebase Analytics 자동 수집 on/off. 내부 빌드에선 꺼서 SaaS에 내부 트래픽이 안 잡히게 한다.
    /// (App Check·Remote Config·Crashlytics는 그대로 — Analytics 수집만 제어)
    public static func setAnalyticsCollectionEnabled(_ enabled: Bool) {
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }

    public static func setUserID(_ userID: String) {
        Crashlytics.crashlytics().setUserID(userID)
    }

    public static func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    public static func recordError(_ error: Error) {
        Crashlytics.crashlytics().record(error: error)
    }
}
