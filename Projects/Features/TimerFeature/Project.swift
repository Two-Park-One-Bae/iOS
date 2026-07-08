import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin
import EnvPlugin
import ConfigPlugin

// MARK: - 버전별 데모 (26+ AlarmKit / <26 커스텀)
//
// 배포 타깃이 iOS 17.0 이라 26 미만 경로가 실제로 존재한다. 두 데모는 알람/LiveActivity
// 전략을 DI에서 강제(force)해, 시뮬레이터 버전과 무관하게 각 경험을 검증한다.
//  - TimerFeatureDemoAlarmKit : AlarmKitAlarmScheduler (26.1+ 시스템 알람) → 26 시뮬에서 실행
//  - TimerFeatureDemoCustom   : CustomAlarmScheduler + 커스텀 스택 activate → 17~25 시뮬에서 실행
// 각 데모는 자체 위젯 익스텐션을 embed 해 잠금화면 Live Activity·Dynamic Island 까지 확인한다.
// 위젯 소스는 앱 타깃(App/Widget)과 동일 파일을 공유(중복 없음).

private let appGroup = "group.app.nursemate.timer"

// App/Widget 과 동일한 위젯 소스 공유
private let widgetSources: SourceFilesList = [
    .glob(.relativeToRoot("Projects/App/Widget/Sources/**"))
]

private let demoEntitlements: Entitlements = .dictionary([
    "com.apple.developer.usernotifications.time-sensitive": .boolean(true),
    "com.apple.security.application-groups": .array([.string(appGroup)]),
])

private let widgetEntitlements: Entitlements = .dictionary([
    "com.apple.security.application-groups": .array([.string(appGroup)]),
])

private func demoInfoPlist(displayName: String) -> InfoPlist {
    .extendingDefault(with: [
        "CFBundleDisplayName": .string(displayName),
        "UILaunchScreen": .dictionary(["UIColorName": "", "UIImageName": ""]),
        "NSSupportsLiveActivities": true,
        "UIBackgroundModes": .array([.string("audio")]),
        "NSAlarmKitUsageDescription": "치료 타이머 종료 알람 데모입니다.",
        "UIApplicationSceneManifest": .dictionary([
            "UIApplicationSupportsMultipleScenes": .boolean(false),
            "UISceneConfigurations": .dictionary([
                "UIWindowSceneSessionRoleApplication": .array([
                    .dictionary([
                        "UISceneConfigurationName": .string("Default Configuration"),
                        "UISceneDelegateClassName": .string("$(PRODUCT_MODULE_NAME).SceneDelegate"),
                    ])
                ])
            ])
        ]),
    ])
}

private func widgetInfoPlist(displayName: String) -> InfoPlist {
    .extendingDefault(with: [
        "CFBundleDisplayName": .string(displayName),
        "NSSupportsLiveActivities": true,
        "NSExtension": .dictionary([
            "NSExtensionPointIdentifier": .string("com.apple.widgetkit-extension")
        ]),
    ])
}

/// 데모 앱 + 위젯 익스텐션 한 쌍
private func demoPair(name: String, bundleSuffix: String, sources: String, displayName: String) -> [Target] {
    let bundleId = "\(Environment.bundlePrefix).timerfeature.\(bundleSuffix)"
    let widgetName = "\(name)Widget"

    let app = Target.target(
        name: name,
        destinations: .iOS,
        product: .app,
        bundleId: bundleId,
        deploymentTargets: Environment.deploymentTarget,
        infoPlist: demoInfoPlist(displayName: displayName),
        sources: [.glob("\(sources)/**")],
        entitlements: demoEntitlements,
        dependencies: [
            .target(name: widgetName),
            .target(name: "TimerFeature"),
            Dep.Features.Timer.Interface,
            Dep.Domain.Domain,
            Dep.Data.Data,
            Dep.Core.Core,
            Dep.Modules.TimerShared.TimerShared,
            Dep.Features.Base.Base,
        ],
        settings: .settings(base: XCConfig.base)
    )

    let widget = Target.target(
        name: widgetName,
        destinations: .iOS,
        product: .appExtension,
        bundleId: "\(bundleId).widget",
        deploymentTargets: Environment.deploymentTarget,
        infoPlist: widgetInfoPlist(displayName: displayName),
        sources: widgetSources,
        entitlements: widgetEntitlements,
        dependencies: [
            Dep.Modules.TimerShared.TimerShared,
        ],
        settings: .settings(base: XCConfig.base)
    )

    return [app, widget]
}

private let demoTargets: [Target] =
    demoPair(name: "TimerFeatureDemoAlarmKit", bundleSuffix: "demo.alarmkit", sources: "DemoAlarmKit/Sources", displayName: "타이머 데모 (AlarmKit)")
    + demoPair(name: "TimerFeatureDemoCustom", bundleSuffix: "demo.custom", sources: "DemoCustom/Sources", displayName: "타이머 데모 (Custom)")

private let demoSchemes: [Scheme] = [
    .scheme(
        name: "TimerFeatureDemoAlarmKit",
        buildAction: .buildAction(targets: [.target("TimerFeatureDemoAlarmKit")]),
        runAction: .runAction(executable: .target("TimerFeatureDemoAlarmKit"))
    ),
    .scheme(
        name: "TimerFeatureDemoCustom",
        buildAction: .buildAction(targets: [.target("TimerFeatureDemoCustom")]),
        runAction: .runAction(executable: .target("TimerFeatureDemoCustom"))
    ),
]

// MARK: - Project

let project = Project.makeModule(
    name: "TimerFeature",
    // 데모는 아래 버전별 커스텀 타깃으로 대체 — makeModule 기본 .demo 는 사용하지 않는다.
    targets: [.staticFramework, .interface, .unitTest],
    internalDependencies: [
        Dep.Features.Timer.Interface,
        Dep.Core.Core,
        Dep.Domain.Domain,
        Dep.Data.Data,
        Dep.Modules.DSKit.DSKit,
        Dep.Modules.TimerShared.TimerShared,
        Dep.Features.Base.Base,
        .SPM.SnapKit,
        .SPM.Then,
    ],
    interfaceDependencies: [
        Dep.Features.Base.Base,
    ],
    extraTargets: demoTargets,
    extraSchemes: demoSchemes
)
