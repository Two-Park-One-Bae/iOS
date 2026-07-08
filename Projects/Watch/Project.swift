import ProjectDescription
import EnvPlugin
import ConfigPlugin
import DependencyPlugin

private let bundleId = "\(Environment.bundlePrefix).app"
private let watchBundleId = "\(bundleId).watchapp"

let project = Project(
    name: "Watch",
    settings: .settings(base: XCConfig.base, configurations: XCConfig.framework),
    targets: [
        // watchOS 10 단일 타깃 SwiftUI 앱(WKApplication). 레거시 watch2App+Extension 아님.
        // 아이폰 앱(App)이 이 타깃을 embed 해 함께 배포·자동 설치한다.
        .target(
            name: "WatchApp",
            destinations: [.appleWatch],
            product: .app,
            bundleId: watchBundleId,
            deploymentTargets: .watchOS("10.0"),
            infoPlist: .extendingDefault(with: [
                "WKApplication": true,
                "WKCompanionAppBundleIdentifier": "\(bundleId)",
            ]),
            sources: ["WatchExtension/Sources/**"],
            resources: [
                "WatchApp/Resources/**",
                "WatchExtension/Resources/**",
            ],
            dependencies: [
                // 폰↔워치 공용 타이머 도메인 — 동기화 스냅샷을 같은 타입으로 디코드
                Dep.Modules.TimerDomain.TimerDomain,
            ],
            settings: .settings(base: XCConfig.base)
        ),
    ]
)
