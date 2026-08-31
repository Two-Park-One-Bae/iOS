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

    /// Crashlytics·Analytics 양쪽에 회원 식별자(**Firebase UID**)를 붙인다.
    ///
    /// GA4 기본값인 app-instance ID 는 재설치 시 새로 발급돼 같은 사람이 둘로 잡힌다.
    /// 그래서 예전엔 Keychain UUID 를 썼는데, 그것도 **사람이 아니라 기기를 센다** —
    /// 한 사람이 두 기기를 쓰면 둘로, 기기를 바꾸면 신규로 잡혔다. 북극성 짝지표가
    /// "주간 케어 활성 **간호사 수**"라 그 차이가 그대로 지표 오차가 된다.
    ///
    /// 로그인이 들어오면서(NM-410) 사람 단위 식별자가 생겼고, 서버도 회원을 같은 값으로
    /// 저장하므로(`AppUserEntity.userId`) 크래시·지표·서버 로그가 한 값으로 이어진다.
    ///
    /// GA4 는 보고 ID 가 `User-ID(Blended)` 로 설정돼 있어야 이 값이 집계에 쓰인다
    /// (docs/NurseMate-Analytics-GSM-Notion.md).
    public static func setUserID(_ userID: String) {
        Crashlytics.crashlytics().setUserID(userID)
        Analytics.setUserID(userID)
    }

    /// GA4 사용자 속성. `nil` 이면 해제한다.
    ///
    /// **보고서에 쓰려면 GA4 콘솔에서 맞춤 측정기준으로 등록해야 한다** — 등록 전 데이터는
    /// 소급 적용되지 않으므로, 값을 보내기 시작하기 전에 등록해 두는 편이 낫다.
    /// 이름은 소문자·언더스코어 규약을 따른다(GA4 제한: 24자).
    public static func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    /// 로그아웃 — 사용자 결합을 끊는다.
    ///
    /// Crashlytics 는 빈 문자열이 해제 규약이다(문서 명시). 다만 **이미 올라간 리포트에서는
    /// 지워지지 않는다** — 탈퇴 사용자의 기록 삭제가 필요하면 Firebase 지원에 문의해야 한다.
    public static func clearUserID() {
        Crashlytics.crashlytics().setUserID("")
        Analytics.setUserID(nil)
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
