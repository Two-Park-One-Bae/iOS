import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin
import EnvPlugin
import ConfigPlugin

let project = Project(
    name: "App",
    settings: .settings(configurations: XCConfig.app),
    targets: [
        .target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "\(Environment.bundlePrefix).app",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": ["UIColorName": "", "UIImageName": ""],
                "UIApplicationSceneManifest": [
                    "UIApplicationSupportsMultipleScenes": false,
                    "UISceneConfigurations": [
                        "UIWindowSceneSessionRoleApplication": [[
                            "UISceneConfigurationName": "Default Configuration",
                            "UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).SceneDelegate",
                        ]]
                    ]
                ],
            ]),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            dependencies: [
                Dep.Features.Home.Feature,
                Dep.Core.Core,
                .project(target: "WatchApp", path: .relativeToRoot("Projects/Watch")),
            ],
            settings: .settings(base: ["DEVELOPMENT_TEAM": "QD353RFHM5"])
        ),
    ]
)
