import FirebaseCore
import FirebaseCrashlytics

public enum FirebaseService {
    public static func configure() {
        FirebaseApp.configure()
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
