import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

let project = Project.makeModule(
    name: "Core",
    targets: [.dynamicFramework, .unitTest],
    externalDependencies: [
        .SPM.FirebaseAnalytics,
        .SPM.FirebaseCrashlytics,
        .SPM.FirebaseRemoteConfig,
        .SPM.FirebaseAppCheck,
        // 소셜 로그인·Bearer 토큰 (NM-410) — FirebaseAuthService 가 감싼다.
        .SPM.FirebaseAuth,
        // GoogleSignIn 은 Firebase 와 같은 정적 라이브러리(AppCheckCore·FBLPromises·GTMSessionFetcher
        // ·GoogleUtilities)를 끌고 온다. 상위 모듈에서 링크하면 사본이 둘이 되어 런타임에 크래시하므로
        // Firebase 를 이미 들고 있는 Core 한 곳에서만 링크한다 (GoogleSignInService 참고).
        .SPM.GoogleSignIn,
        .SPM.AmplitudeSwift,
    ]
)
