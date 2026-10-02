import ProjectDescription

public extension TargetDependency {
    struct SPM {
        public static let Alamofire = TargetDependency.external(name: "Alamofire")
        public static let Moya = TargetDependency.external(name: "Moya")
        public static let CombineMoya = TargetDependency.external(name: "CombineMoya")
        public static let SnapKit = TargetDependency.external(name: "SnapKit")
        public static let Kingfisher = TargetDependency.external(name: "Kingfisher")
        public static let FirebaseAnalytics = TargetDependency.external(name: "FirebaseAnalytics")
        public static let FirebaseCrashlytics = TargetDependency.external(name: "FirebaseCrashlytics")
        public static let FirebaseRemoteConfig = TargetDependency.external(name: "FirebaseRemoteConfig")
        public static let FirebaseAppCheck = TargetDependency.external(name: "FirebaseAppCheck")
        public static let FirebaseAuth = TargetDependency.external(name: "FirebaseAuth")
        public static let Lottie = TargetDependency.external(name: "Lottie")
        public static let Then = TargetDependency.external(name: "Then")

        // MARK: - 소셜 로그인 (NM-410)

        public static let GoogleSignIn = TargetDependency.external(name: "GoogleSignIn")
        public static let KakaoSDKCommon = TargetDependency.external(name: "KakaoSDKCommon")
        public static let KakaoSDKAuth = TargetDependency.external(name: "KakaoSDKAuth")
        public static let KakaoSDKUser = TargetDependency.external(name: "KakaoSDKUser")

        // MARK: - 광고 어트리뷰션 (NM-465)

        public static let FacebookCore = TargetDependency.external(name: "FacebookCore")
    }
}
