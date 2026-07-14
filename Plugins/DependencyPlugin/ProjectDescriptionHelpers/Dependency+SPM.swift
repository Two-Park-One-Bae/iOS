import ProjectDescription

public extension TargetDependency {
    struct SPM {
        public static let Alamofire = TargetDependency.external(name: "Alamofire")
        public static let Moya = TargetDependency.external(name: "Moya")
        public static let CombineMoya = TargetDependency.external(name: "CombineMoya")
        public static let SnapKit = TargetDependency.external(name: "SnapKit")
        public static let Kingfisher = TargetDependency.external(name: "Kingfisher")
        public static let AmplitudeSwift = TargetDependency.external(name: "AmplitudeSwift")
        public static let FirebaseAnalytics = TargetDependency.external(name: "FirebaseAnalytics")
        public static let FirebaseCrashlytics = TargetDependency.external(name: "FirebaseCrashlytics")
        public static let FirebaseRemoteConfig = TargetDependency.external(name: "FirebaseRemoteConfig")
        public static let Lottie = TargetDependency.external(name: "Lottie")
        public static let Then = TargetDependency.external(name: "Then")
        public static let Clarity = TargetDependency.external(name: "Clarity")
    }
}
