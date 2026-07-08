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
                "NSSupportsLiveActivities": true,
                "UIBackgroundModes": ["audio"],
                "NSAlarmKitUsageDescription": "치료 타이머 종료 알람을 예약·알림하기 위해 필요합니다.",
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
            entitlements: .dictionary([
                "com.apple.developer.usernotifications.time-sensitive": .boolean(true),
                "com.apple.security.application-groups": .array([.string("group.app.nursemate.timer")])
            ]),
            dependencies: [
                Dep.Features.Home.Feature,
                Dep.Features.TabBar.Feature,
                Dep.Features.DrugIdentification.Feature,
                Dep.Features.Timer.Feature,
                Dep.Core.Core,
                .target(name: "TimerWidget"),
                // 워치 앱 embed — 폰 설치 시 워치에 자동 설치(별도 다운 X),
                // 폰↔워치 companion 쌍으로 인식돼 WCSession 동기화가 성립한다.
                .target(name: "WatchApp"),
            ],
            settings: .settings(base: XCConfig.base)
        ),
        // watchOS 10 단일 타깃 SwiftUI 앱(WKApplication). 소스는 Projects/Watch/ 에 그대로 유지.
        // App 과 같은 프로젝트에 둬야 Tuist 가 "Embed Watch Content" 로 올바르게 embed 한다.
        .target(
            name: "WatchApp",
            destinations: [.appleWatch],
            product: .app,
            bundleId: "\(Environment.bundlePrefix).app.watchapp",
            deploymentTargets: .watchOS("10.0"),
            infoPlist: .extendingDefault(with: [
                "WKApplication": true,
                "WKCompanionAppBundleIdentifier": "\(Environment.bundlePrefix).app",
            ]),
            sources: ["../Watch/WatchExtension/Sources/**"],
            resources: [
                "../Watch/WatchApp/Resources/**",
                "../Watch/WatchExtension/Resources/**",
            ],
            dependencies: [
                // 폰·워치 공용 타이머 도메인 — 동기화 스냅샷을 같은 타입으로 디코드
                Dep.Modules.TimerDomain.TimerDomain,
            ],
            settings: .settings(base: XCConfig.base)
        ),
        // 잠금화면 Live Activity · Dynamic Island (spec: 잠금화면 실시간 표시)
        .target(
            name: "TimerWidget",
            destinations: .iOS,
            product: .appExtension,
            bundleId: "\(Environment.bundlePrefix).app.timerwidget",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "널스메이트 타이머",
                "NSSupportsLiveActivities": true,
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
                ],
            ]),
            sources: ["Widget/Sources/**"],
            entitlements: .dictionary([
                "com.apple.security.application-groups": .array([.string("group.app.nursemate.timer")])
            ]),
            // 공유 계약 모듈만 링크 — Live Activity/AlarmKit 타입을 TimerFeature와 동일하게 맞춘다.
            dependencies: [
                Dep.Modules.TimerShared.TimerShared,
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
