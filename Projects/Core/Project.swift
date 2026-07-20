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
        .SPM.AmplitudeSwift,
        .SPM.Clarity,
    ]
)
