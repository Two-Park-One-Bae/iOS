import ProjectDescription
import EnvPlugin
import ConfigPlugin

private let bundleId = "\(Environment.bundlePrefix).app"
private let watchBundleId = "\(bundleId).watchapp"

let project = Project(
    name: "Watch",
    settings: .settings(base: XCConfig.base, configurations: XCConfig.framework),
    targets: [
        .target(
            name: "WatchApp",
            destinations: [.appleWatch],
            product: .watch2App,
            bundleId: watchBundleId,
            deploymentTargets: .watchOS("10.0"),
            infoPlist: .extendingDefault(with: [
                "WKCompanionAppBundleIdentifier": "\(bundleId)",
            ]),
            sources: [],
            resources: ["WatchApp/Resources/**"],
            dependencies: [
                .target(name: "WatchExtension"),
            ],
            settings: .settings(base: XCConfig.base)
        ),
        .target(
            name: "WatchExtension",
            destinations: [.appleWatch],
            product: .watch2Extension,
            bundleId: "\(watchBundleId).extension",
            deploymentTargets: .watchOS("10.0"),
            infoPlist: .extendingDefault(with: [
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.watchkit",
                    "NSExtensionAttributes": [
                        "WKAppBundleIdentifier": "\(watchBundleId)",
                    ],
                ],
            ]),
            sources: ["WatchExtension/Sources/**"],
            resources: ["WatchExtension/Resources/**"],
            settings: .settings(base: XCConfig.base)
        ),
    ]
)
