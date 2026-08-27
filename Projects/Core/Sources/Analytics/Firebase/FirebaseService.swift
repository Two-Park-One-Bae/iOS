import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics

public enum FirebaseService {
    public static func configure() {
        FirebaseApp.configure()
    }

    /// 구글 로그인용 OAuth 클라이언트 ID (NM-410).
    ///
    /// Firebase 콘솔에서 Google 공급자를 켜야 `GoogleService-Info.plist` 에 생긴다 — 없으면 nil.
    /// GoogleSignIn SDK 가 이 값을 요구하는데, 그것만을 위해 상위 모듈이 FirebaseCore 를 직접
    /// import 하게 두지 않으려고 여기서 노출한다.
    public static var googleClientID: String? {
        FirebaseApp.app()?.options.clientID
    }

    /// Firebase Analytics 자동 수집 on/off. 내부 빌드에선 꺼서 SaaS에 내부 트래픽이 안 잡히게 한다.
    /// (App Check·Remote Config·Crashlytics는 그대로 — Analytics 수집만 제어)
    public static func setAnalyticsCollectionEnabled(_ enabled: Bool) {
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }

    /// Crashlytics·Analytics 양쪽에 기기 식별자(Keychain UUID)를 붙인다.
    /// GA4 기본값인 app-instance ID 는 재설치 시 새로 발급돼 같은 사람이 둘로 잡힌다.
    public static func setUserID(_ userID: String) {
        Crashlytics.crashlytics().setUserID(userID)
        Analytics.setUserID(userID)
    }

    /// GA4 커스텀 이벤트 전송. 내부 빌드는 setAnalyticsCollectionEnabled(false)라 실제 전송이 no-op이 된다.
    public static func log(event name: String, _ params: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: params)
    }

    public static func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    public static func recordError(_ error: Error) {
        Crashlytics.crashlytics().record(error: error)
    }
}
