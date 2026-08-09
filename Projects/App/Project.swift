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
                // 홈 화면 표시 이름 — 로케일 무관 영어 단일값.
                "CFBundleDisplayName": "NurseMate",
                "CFBundleShortVersionString": "1.0.2",
                "ITSAppUsesNonExemptEncryption": false,
                "AMPLITUDE_API_KEY": "$(AMPLITUDE_API_KEY)",
                "BASE_URL": "$(BASE_URL)",
                // Firebase Analytics 자동수집을 빌드 구성으로 제어(NM-364). 내부(Debug·beta_internal)=NO →
                // FirebaseApp.configure() 전부터 꺼져 first_open 등 'leak 창' 자체가 없다. 외부·프로덕션=YES.
                "FIREBASE_ANALYTICS_COLLECTION_ENABLED": "$(FIREBASE_ANALYTICS_ENABLED)",
                "NSCameraUsageDescription": "알약 사진 촬영을 위해 카메라 접근이 필요합니다.",
                "NSPhotoLibraryUsageDescription": "앨범에서 알약 사진을 선택하기 위해 접근이 필요합니다.",
                // 위젯 "+" 딥링크(nursemate://timer/preset/pick) 로 앱을 여는 URL 스킴 (NM-302)
                "CFBundleURLTypes": [[
                    "CFBundleURLName": "\(Environment.bundlePrefix).app",
                    "CFBundleURLSchemes": ["nursemate"],
                ]],
                "NSSupportsLiveActivities": true,
                // UIBackgroundModes: audio 는 선언하지 않는다 (App Store 2.5.4).
                // 무음 루프로 앱을 백그라운드에 살려두던 방식이 리젝 사유였고, 타이머를
                // AlarmKit 전용으로 바꾸면서 그 경로 자체가 사라졌다.
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
                "CFBundleDisplayName": "NurseMate",
                "CFBundleShortVersionString": "1.0.2",
                // WKBackgroundModes: alarm 은 선언하지 않는다.
                // 26.1 미만 폰을 위해 워치가 WKExtendedRuntimeSession 을 예약하던 폴백이 있었으나,
                // 타이머가 AlarmKit 전용이 되면서(NM-381) 그 경로가 사라졌다. 26.1+ 는 AlarmKit 이
                // 워치까지 울린다 — 워치가 자체 세션을 켤 일이 없다.
                // 컴플리케이션 딥링크(nursemate://presets) 를 앱이 onOpenURL 로 받기 위한 스킴 (NM-303)
                "CFBundleURLTypes": [[
                    "CFBundleURLSchemes": ["nursemate"],
                ]],
            ]),
            sources: ["../Watch/WatchExtension/Sources/**"],
            resources: [
                "../Watch/WatchApp/Resources/**",
                "../Watch/WatchExtension/Resources/**",
            ],
            dependencies: [
                // 폰·워치 공용 타이머 도메인 — 동기화 스냅샷을 같은 타입으로 디코드
                Dep.Modules.TimerDomain.TimerDomain,
                // 워치 컴플리케이션 embed — 워치 앱 설치 시 함께 설치 (NM-303)
                .target(name: "WatchComplication"),
            ],
            // configurations 를 붙여야 xcconfig 의 DEVELOPMENT_TEAM·자동서명이 적용된다.
            // (없으면 워치 앱에 프로비저닝 프로파일이 안 잡혀 "could not be installed")
            settings: .settings(base: XCConfig.base, configurations: XCConfig.app)
        ),
        // watchOS 컴플리케이션(WidgetKit accessory) — 시계 페이스 → 프리셋 그리드 딥링크 (NM-303)
        .target(
            name: "WatchComplication",
            destinations: [.appleWatch],
            product: .appExtension,
            bundleId: "\(Environment.bundlePrefix).app.watchapp.presetcomplication",
            deploymentTargets: .watchOS("10.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "NurseMate",
                "CFBundleShortVersionString": "1.0.2",
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.widgetkit-extension",
                ],
            ]),
            sources: ["../Watch/WatchComplication/Sources/**"],
            settings: .settings(base: XCConfig.base, configurations: XCConfig.app)
        ),
        // 잠금화면 Live Activity · Dynamic Island (spec: 잠금화면 실시간 표시)
        .target(
            name: "TimerWidget",
            destinations: .iOS,
            product: .appExtension,
            bundleId: "\(Environment.bundlePrefix).app.timerwidget",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "NurseMate",
                "CFBundleShortVersionString": "1.0.2",
                "NSSupportsLiveActivities": true,
                // 위젯에서 시작한 타이머의 AlarmKit 예약(iOS 26.1+)에 필요 (NM-302)
                "NSAlarmKitUsageDescription": "치료 타이머 종료 알람을 예약·알림하기 위해 필요합니다.",
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
                ],
            ]),
            sources: ["Widget/Sources/**"],
            entitlements: .dictionary([
                "com.apple.security.application-groups": .array([.string("group.app.nursemate.timer")])
            ]),
            // 공유 계약 모듈 링크 — Live Activity/AlarmKit 타입을 TimerFeature와 동일하게 맞춘다.
            // TimerDomain — 프리셋 위젯(NM-302)이 TimerPresetModel/TreatmentTimerModel 을 그대로 사용.
            dependencies: [
                Dep.Modules.TimerShared.TimerShared,
                Dep.Modules.TimerDomain.TimerDomain,
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
            runAction: .runAction(
                executable: .target("App"),
                // App Check 디버그 토큰을 개발 실행 시 주입한다 (NM-325).
                // 개발 빌드(시뮬·실기기)는 App Check 디버그 프로바이더를 쓰는데, 토큰이 매번 랜덤 생성돼
                // Firebase Console 재등록을 반복하게 된다. 이를 막으려 고정 토큰을 env var로 넣는다.
                // 실제 토큰 값은 gitignore된 XCConfig/Secrets.xcconfig 의 APP_CHECK_DEBUG_TOKEN 에만 두고,
                // 여기·스킴엔 `$(...)` 참조만 들어가므로 커밋돼도 안전하다.
                // (Secrets.xcconfig 는 Debug/Release xcconfig 가 #include → App 타깃 빌드세팅으로 확장됨)
                arguments: .arguments(
                    environmentVariables: [
                        "FIRAAppCheckDebugToken": "$(APP_CHECK_DEBUG_TOKEN)"
                    ]
                ),
                // 스킴 env var 의 `$(...)` 를 App 타깃 빌드세팅 기준으로 확장한다.
                expandVariableFromTarget: .target("App")
            )
        )
    ]
)
