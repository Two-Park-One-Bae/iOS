import ProjectDescription
import EnvPlugin

private let bundleId = "\(Environment.bundlePrefix).app"
private let watchBundleId = "\(bundleId).watchapp"

let project = Project(
    name: "Watch",
    targets: [
        .target(
            name: "WatchApp",
            destinations: [.appleWatch],
            product: .watch2App,
            bundleId: watchBundleId,
            deploymentTargets: .watchOS("10.0"),
            infoPlist: .extendingDefault(with: [
                "WKApplication": true,
                "WKCompanionAppBundleIdentifier": "\(bundleId)",
            ]),
            sources: [],
            resources: ["WatchApp/Resources/**"],
            dependencies: [
                .target(name: "WatchExtension"),
            ]
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
            resources: ["WatchExtension/Resources/**"]
        ),
    ]
)
