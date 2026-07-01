import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin
import EnvPlugin
import ConfigPlugin

let project = Project(
    name: "App",
    settings: .settings(base: XCConfig.base, configurations: XCConfig.app),
    targets: [
        .target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "\(Environment.bundlePrefix).app",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .extendingDefault(with: [
                "ITSAppUsesNonExemptEncryption": false,
                "AMPLITUDE_API_KEY": "$(AMPLITUDE_API_KEY)",
                "BASE_URL": "$(BASE_URL)",
                "CLARITY_PROJECT_ID": "$(CLARITY_PROJECT_ID)",
                "NSCameraUsageDescription": "알약 사진 촬영을 위해 카메라 접근이 필요합니다.",
                "NSPhotoLibraryUsageDescription": "앨범에서 알약 사진을 선택하기 위해 접근이 필요합니다.",
                "UIUserInterfaceStyle": "Light",
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
                Dep.Features.TabBar.Feature,
                Dep.Features.DrugIdentification.Feature,
                Dep.Core.Core,
            ],
            settings: .settings(base: XCConfig.base)
        ),
        .target(
            name: "AppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "\(Environment.bundlePrefix).app.tests",
            deploymentTargets: Environment.deploymentTarget,
            sources: ["Tests/**"],
            dependencies: [],
            settings: .settings(base: ["TEST_HOST": ""])
        ),
    ],
    schemes: [
        .scheme(
            name: "App",
            buildAction: .buildAction(targets: [.target("App")]),
            testAction: .targets([.testableTarget(target: .target("AppTests"))]),
            runAction: .runAction(executable: .target("App"))
        )
    ]
)
