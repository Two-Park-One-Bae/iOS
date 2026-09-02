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
            destinations: [.iPhone],
            product: .app,
            bundleId: "\(Environment.bundlePrefix).app",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .extendingDefault(with: [
                // 홈 화면 표시 이름 — 로케일 무관 영어 단일값.
                "CFBundleDisplayName": "NurseMate",
                "CFBundleShortVersionString": "1.1.1",
                "ITSAppUsesNonExemptEncryption": false,
                "AMPLITUDE_API_KEY": "$(AMPLITUDE_API_KEY)",
                "BASE_URL": "$(BASE_URL)",
                // Firebase Analytics 자동수집을 빌드 구성으로 제어(NM-364). 내부(Debug·beta_internal)=NO →
                // FirebaseApp.configure() 전부터 꺼져 first_open 등 'leak 창' 자체가 없다. 외부·프로덕션=YES.
                "FIREBASE_ANALYTICS_COLLECTION_ENABLED": "$(FIREBASE_ANALYTICS_ENABLED)",
                // 자동 screen_view 수집을 끈다. 이 앱에선 비용만 크고 얻는 게 없다.
                //
                // 무엇을 잃나 — ga_screen_class 는 **뷰컨트롤러 클래스명**이 그대로 들어간다.
                // 화면 단위 분석은 우리가 직접 찍는 button_tap.screen 과 퍼널 이벤트
                // (pill_identify_started/result/complete …)로 이미 하고 있고, 그쪽이
                // 의미 있는 이름을 쓴다. VC 클래스명 축은 리팩터링 때마다 값이 갈라진다.
                //
                // 무엇을 아끼나 — QA 주행 로그 기준 screen_view 가 전체 이벤트의 51%
                // (349/680)로 단일 최대 소스다. 자동수집 전체는 87.5%.
                //
                // 활성 사용자 지표에는 영향이 없다 — GA4 의 DAU/WAU/MAU 는 first_open
                // 또는 user_engagement 로 정의되며 screen_view 는 조건에 없다.
                // 신규 설치 실측으로도 두 이벤트가 그대로 나가는 것을 확인했다.
                "FirebaseAutomaticScreenReportingEnabled": false,
                "NSCameraUsageDescription": "알약 사진 촬영을 위해 카메라 접근이 필요합니다.",
                "NSPhotoLibraryUsageDescription": "앨범에서 알약 사진을 선택하기 위해 접근이 필요합니다.",
                // 카카오 SDK 초기화 키 (NM-410). 값은 gitignore 된 Secrets.xcconfig 에만 둔다.
                "KAKAO_NATIVE_APP_KEY": "$(KAKAO_NATIVE_APP_KEY)",
                // 앱을 여는 URL 스킴 세 갈래.
                //   nursemate                 위젯 "+" 딥링크 (NM-302)
                //   kakao{네이티브앱키}         카카오톡 로그인 후 복귀 (NM-410)
                //   $(GOOGLE_REVERSED_CLIENT_ID)  구글 로그인 후 복귀 — Firebase 콘솔에서 구글 공급자를
                //                             켜야 GoogleService-Info.plist 에 REVERSED_CLIENT_ID 가 생긴다.
                "CFBundleURLTypes": [[
                    "CFBundleURLName": "\(Environment.bundlePrefix).app",
                    "CFBundleURLSchemes": [
                        "nursemate",
                        "kakao$(KAKAO_NATIVE_APP_KEY)",
                        "$(GOOGLE_REVERSED_CLIENT_ID)",
                    ],
                ]],
                // 카카오톡 앱이 설치돼 있는지 조회하려면 스킴을 미리 선언해야 한다.
                // 없으면 isKakaoTalkLoginAvailable() 이 항상 false 가 되어 웹 로그인으로만 흐른다.
                "LSApplicationQueriesSchemes": ["kakaokompassauth", "kakaolink"],
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
                "com.apple.security.application-groups": .array([.string("group.app.nursemate.timer")]),
                // Apple 로그인 (NM-410). Apple Developer 의 App ID 에서도 함께 켜야 한다.
                "com.apple.developer.applesignin": .array([.string("Default")]),
            ]),
            // GoogleService-Info.plist 는 Resources 가 아니라 Firebase/<구성>/ 에 둔다.
            // 두 벌을 다 번들에 넣으면 Firebase 가 루트에서 못 찾으므로, 빌드 후 하나만 복사한다.
            // (Crashlytics 가 파일명을 하드코딩해 이름 분리 방식은 쓸 수 없다 — 디렉터리로 나눈다)
            scripts: [
                .post(
                    script: """
                    set -euo pipefail
                    SRC="${SRCROOT}/Firebase/${FIREBASE_ENV}/GoogleService-Info.plist"
                    DST="${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/GoogleService-Info.plist"
                    if [ ! -f "$SRC" ]; then
                      echo "error: GoogleService-Info.plist 가 없다 — $SRC"
                      exit 1
                    fi
                    cp "$SRC" "$DST"
                    echo "Firebase 구성: ${FIREBASE_ENV}"
                    """,
                    name: "Firebase 구성 선택",
                    basedOnDependencyAnalysis: false
                )
            ],
            dependencies: [
                Dep.Features.Auth.Feature,
                Dep.Features.Home.Feature,
                Dep.Features.TabBar.Feature,
                Dep.Features.DrugIdentification.Feature,
                Dep.Features.Timer.Feature,
                Dep.Core.Core,
                // AppCoordinator 가 로그아웃·탈퇴 확인 다이얼로그를 직접 띄운다 (NM-410)
                Dep.Modules.DSKit.DSKit,
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
                "CFBundleShortVersionString": "1.1.1",
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
                "CFBundleShortVersionString": "1.1.1",
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
            destinations: [.iPhone],
            product: .appExtension,
            bundleId: "\(Environment.bundlePrefix).app.timerwidget",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "NurseMate",
                "CFBundleShortVersionString": "1.1.1",
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
            destinations: [.iPhone],
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
                    ],
                    // 분석 QA용 실행 인자 — **꺼진 채로** 스킴에 미리 넣어 둔다.
                    // -FIRDebugEnabled: Firebase DebugView 에 실시간 표시
                    // -FIRAnalyticsDebugEnabled: 이벤트·파라미터를 콘솔(os_log)에 상세 출력
                    //
                    // 기본을 꺼 두는 이유 — 켜 두면 모든 개발 실행이 DebugView 로 흘러 QA 세션과 섞인다.
                    // 미리 넣어 두는 이유 — 매번 손으로 타이핑하면 오타가 나고, tuist generate 때마다
                    // 날아간다. 스킴 편집기에서 체크박스만 켜면 되게 해 둔다.
                    launchArguments: [
                        .launchArgument(name: "-FIRDebugEnabled", isEnabled: false),
                        .launchArgument(name: "-FIRAnalyticsDebugEnabled", isEnabled: false)
                    ]
                ),
                // 스킴 env var 의 `$(...)` 를 App 타깃 빌드세팅 기준으로 확장한다.
                expandVariableFromTarget: .target("App")
            )
        )
    ]
)
