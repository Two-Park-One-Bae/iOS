import ProjectDescription

// MARK: - 프로젝트 설정 (새 앱 시작 시 이 값만 변경)
let appName = "Application"
let bundleId = "app.kyulabs.template"
let deploymentTarget = "26.0"
let watchOSDeploymentTarget = "11.0"
let destinations: Set<Destination> = [.iPhone, .iPad]

// MARK: - Project

let project = Project(
    name: "Application",
    settings: .settings(
        base: [
            "MARKETING_VERSION": "1.0.0",
            "CURRENT_PROJECT_VERSION": "1",
            "SWIFT_VERSION": "6.0",
        ]
    ),
    targets: [
        // MARK: - Shared
        .target(
            name: "Shared",
            destinations: destinations,
            product: .staticFramework,
            bundleId: "\(bundleId).shared",
            deploymentTargets: .iOS(deploymentTarget),
            infoPlist: .default,
            sources: ["Sources/Shared/**"],
            resources: ["Sources/Shared/Resources/**"],
            dependencies: []
        ),
        // MARK: - Feature
        .target(
            name: "Feature",
            destinations: destinations,
            product: .staticFramework,
            bundleId: "\(bundleId).feature",
            deploymentTargets: .iOS(deploymentTarget),
            infoPlist: .default,
            sources: ["Sources/Feature/**"],
            dependencies: [
                .target(name: "Shared"),
            ]
        ),
        // MARK: - ServiceApp
        .target(
            name: "ServiceApp",
            destinations: destinations,
            product: .app,
            bundleId: bundleId,
            deploymentTargets: .iOS(deploymentTarget),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [
                    "UIColorName": "",
                    "UIImageName": "",
                ],
                "UISupportedInterfaceOrientations": [
                    "UIInterfaceOrientationPortrait",
                ],
            ]),
            sources: ["Sources/ServiceApp/**"],
            resources: ["Resources/**"],
            dependencies: [
                .target(name: "Feature"),
                .target(name: "WatchApp"),
            ],
            settings: .settings(
                base: [
                    "DEVELOPMENT_TEAM": "QD353RFHM5",
                    "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": true,
                    "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": true,
                    "INFOPLIST_KEY_UILaunchScreen_Generation": true,
                    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": [
                        "UIInterfaceOrientationPortrait",
                        "UIInterfaceOrientationLandscapeLeft",
                        "UIInterfaceOrientationLandscapeRight",
                    ],
                    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": [
                        "UIInterfaceOrientationPortrait",
                        "UIInterfaceOrientationPortraitUpsideDown",
                        "UIInterfaceOrientationLandscapeLeft",
                        "UIInterfaceOrientationLandscapeRight",
                    ],
                ]
            )
        ),

        // MARK: - WatchApp (stub)
        .target(
            name: "WatchApp",
            destinations: [.appleWatch],
            product: .watch2App,
            bundleId: "\(bundleId).watchapp",
            deploymentTargets: .watchOS(watchOSDeploymentTarget),
            infoPlist: .extendingDefault(with: [
                "WKApplication": true,
                "WKCompanionAppBundleIdentifier": .string(bundleId),
            ]),
            resources: ["WatchApp/Resources/**"],
            dependencies: [
                .target(name: "WatchExtension"),
            ],
            settings: .settings(
                base: [
                    "DEVELOPMENT_TEAM": "QD353RFHM5",
                ]
            )
        ),

        // MARK: - WatchExtension
        .target(
            name: "WatchExtension",
            destinations: [.appleWatch],
            product: .watch2Extension,
            bundleId: "\(bundleId).watchapp.watchkitextension",
            deploymentTargets: .watchOS(watchOSDeploymentTarget),
            infoPlist: .extendingDefault(with: [
                "NSExtension": .dictionary([
                    "NSExtensionPointIdentifier": .string("com.apple.watchkit"),
                    "NSExtensionAttributes": .dictionary([
                        "WKAppBundleIdentifier": .string("\(bundleId).watchapp"),
                    ]),
                ]),
            ]),
            sources: ["WatchExtension/Sources/**"],
            resources: ["WatchExtension/Resources/**"],
            dependencies: [],
            settings: .settings(
                base: [
                    "DEVELOPMENT_TEAM": "QD353RFHM5",
                ]
            )
        ),
    ]
)
