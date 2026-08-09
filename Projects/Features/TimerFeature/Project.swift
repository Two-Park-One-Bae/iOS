import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin
import EnvPlugin
import ConfigPlugin

// MARK: - 데모 (AlarmKit)
//
// 타이머는 iOS 26.1+ 전용이다 — 무음·잠금·앱 종료를 모두 관통하는 시스템 알람이 있어야
// 처치 시각을 보장할 수 있어, 그 미만에서 쓰던 커스텀 스택(로컬 알림 + 백그라운드 오디오)은
// 제거했다. 따라서 커스텀 경로 검증용 TimerFeatureDemoCustom 도 함께 사라졌다.
//  - TimerFeatureDemoAlarmKit : AlarmKitAlarmScheduler → 26.1+ 시뮬/기기에서 실행
// 데모는 자체 위젯 익스텐션을 embed 해 잠금화면 카운트다운·Dynamic Island 까지 확인한다.
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
        // audio 백그라운드 모드는 본 앱과 맞춰 선언하지 않는다 (App Store 2.5.4).
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

private let demoSchemes: [Scheme] = [
    .scheme(
        name: "TimerFeatureDemoAlarmKit",
        buildAction: .buildAction(targets: [.target("TimerFeatureDemoAlarmKit")]),
        runAction: .runAction(executable: .target("TimerFeatureDemoAlarmKit"))
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
