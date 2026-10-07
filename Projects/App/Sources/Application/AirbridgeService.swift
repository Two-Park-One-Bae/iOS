//
//  AirbridgeService.swift
//  App
//

import UIKit
import StoreKit
import AppTrackingTransparency

import Airbridge
import Core

/// 에어브릿지 SDK — 유입 경로 측정(설치 어트리뷰션·트래킹 링크 딥링크)과 가입 이벤트.
///
/// ## 왜 App 타깃에만 있나
///
/// 에어브릿지 문서가 Tuist 의 XcodeProj 기반 통합(Tuist/Package.swift)을 지원하지 않는다고 해서
/// App 프로젝트의 `packages` 로 받았다. 그래서 다른 모듈은 이 SDK 를 import 할 수 없고,
/// 에어브릿지에 닿는 호출은 전부 여기를 거친다. 가입 이벤트는 Core 의 `AttributionTracking` 구현
/// (`Tracker`)을 DI 로 주입해 AuthFeature 가 부른다.
///
/// ## App Store 설치본만 수집한다
///
/// Firebase 와 달리 에어브릿지 앱은 **운영 하나뿐**이다(dev 앱이 없다). 그래서 빌드 구성이 아니라
/// **설치 경로**로 가른다 — `AppTransaction` 환경이 `.production`(App Store 다운로드)일 때만 수집을 켠다.
/// TestFlight·App Review 는 `.sandbox`, Xcode 실행은 `.xcode` 라 심사 기기와 QA 가 통째로 빠진다
/// (설치 이벤트 포함 — 계정으로 거르는 방식은 로그인 전 이벤트를 못 막는다).
///
/// SDK 는 수집을 멈춘 채 초기화하고(`setAutoStartTrackingEnabled(false)`), 확인되면 `startTracking()`.
/// 설치 이벤트는 어차피 ATT 응답을 기다리므로 확인하는 동안 잃는 이벤트는 없다.
///
/// - 확인 **실패**(첫 실행 오프라인 등)면 이번 실행은 수집한다 — 실사용자를 잃는 쪽이 더 비싸다.
///   판정은 저장하지 않고 매 실행 다시 확인하므로, 테스트 기기였다면 다음 실행부터 멈춘다.
///   (저장하면 TestFlight → App Store 로 갈아탄 기기가 영영 수집되지 않는다.
///    `AppTransaction` 은 StoreKit 이 기기에 캐시해 두 번째 실행부터는 오프라인에서도 바로 온다.)
/// - SDK 연동 검증은 스킴의 `-AirbridgeEnabled` 실행 인자로 우회한다 — 이벤트가 **운영 앱**으로 간다.
enum AirbridgeService {

    /// 대시보드 앱 이름(서브도메인). 유니버설 링크 도메인 `nursemate.airbridge.io` 와 같은 값이다.
    private static let appName = "nursemate"

    /// SDK 가 초기화됐는지. 꺼져 있으면 아래 호출은 모두 아무것도 하지 않는다.
    private(set) static var isEnabled = false

    private static var activeObserver: NSObjectProtocol?

    /// `application(_:didFinishLaunchingWithOptions:)` 에서 **가장 먼저** 호출한다(에어브릿지 요구사항).
    static func configure() {
        // ATT 는 에어브릿지 여부와 무관하게 띄운다 — 내부 빌드에서도 실제 사용자와 같은 흐름을 QA 하기 위함.
        requestTrackingAuthorizationOnFirstActive()

        guard let token = Bundle.main.object(forInfoDictionaryKey: "AIRBRIDGE_APP_TOKEN") as? String,
              !token.isEmpty else {
            #if DEBUG
            print("⚠️ AIRBRIDGE_APP_TOKEN 이 비어 있다 — XCConfig/Secrets.xcconfig 에 App SDK Token 을 넣을 것.")
            #endif
            return
        }

        // ATT 응답을 기다리는 시간. 응답 전에 설치 이벤트가 나가면 IDFA 가 빠져 성과 측정이 어렵다.
        // 앱을 열자마자 프롬프트를 띄우므로 기본값(30초)이면 충분하다.
        let option = AirbridgeOptionBuilder(name: appName, token: token)
            .setAutoDetermineTrackingAuthorizationTimeout(second: 30)
            .setAutoStartTrackingEnabled(false)
            // ⚠️ **에어브릿지 딥링크만 센다.** 위젯(nursemate://timer…)으로 앱을 열 때마다
            //    딥링크 유입이 하나씩 생기지 않게 한다 (Android NM-543 과 같은 설정).
            .setTrackAirbridgeDeeplinkOnlyEnabled(true)
            .build()
        Airbridge.initializeSDK(option: option)
        isEnabled = true

        Task { await startTrackingIfAppStoreInstall() }
    }

    // MARK: - 설치 경로

    private static func startTrackingIfAppStoreInstall() async {
        if ProcessInfo.processInfo.arguments.contains("-AirbridgeEnabled") {
            Airbridge.startTracking()
            return
        }
        do {
            // 서명 검증 실패여도 환경 값은 읽는다 — 여기선 위변조 방어가 아니라 설치 경로 구분이 목적이다.
            let environment: AppStore.Environment = switch try await AppTransaction.shared {
            case let .verified(transaction):   transaction.environment
            case let .unverified(transaction, _): transaction.environment
            }
            if environment == .production {
                Airbridge.startTracking()
            }
        } catch {
            // 확인 실패 — 실사용자로 간주해 이번 실행은 수집한다(위 타입 주석 참고).
            Airbridge.startTracking()
        }
    }

    // MARK: - 인앱 이벤트

    /*
     보내는 이벤트는 **가입 하나**다 (Android NM-543 과 같다).

     에어브릿지는 "이 사용자가 어디서 왔나"만 잰다 — 앱 안의 행동은 Firebase 가 이미 잰다.
     둘을 한 파사드(`AppAnalytics`)에 합치지 않고 `AttributionTracking` 을 따로 둔 이유도 같다.
     사용자 ID·이메일도 싣지 않는다. 이벤트를 늘리려면 Android 와 이름·시점을 맞출 것.
     */
    struct Tracker: AttributionTracking {
        func signUp() {
            guard AirbridgeService.isEnabled else { return }
            Airbridge.trackEvent(category: AirbridgeCategory.SIGN_UP)
        }
    }

    // MARK: - 딥링크

    /*
     에어브릿지 딥링크는 세 가지 모양으로 들어온다 —
       https://nursemate.airbridge.io/…, https://nursemate.abr.ge/… (유니버설 링크)
       nursemate://…?airbridge_referrer=… (인앱 브라우저 등에서 쓰는 스킴)
     SDK 가 어느 쪽이든 트래킹 링크에 넣어 둔 원래 스킴 딥링크(nursemate://timer/…)로 되돌려 준다.
     그래서 앱은 기존 `nursemate://` 라우팅 하나만 유지하면 된다.

     반환값이 true 면 에어브릿지 링크였다는 뜻 — 호출부는 기존 라우팅으로 넘기지 않는다.
     변환된 URL 은 onOpen 으로 따로(비동기일 수 있다) 온다.
     */

    /// 콜드런치 — 스킴·유니버설 링크 모두 `connectionOptions` 로 온다.
    static func handle(connectionOptions: UIScene.ConnectionOptions, onOpen: @escaping (URL) -> Void) -> Bool {
        guard isEnabled else { return false }
        Airbridge.trackDeeplink(connectionOptions: connectionOptions)
        return Airbridge.handleDeeplink(connectionOptions: connectionOptions, onSuccess: onOpen)
    }

    /// 실행 중 — 스킴 딥링크.
    static func handle(openURLContexts: Set<UIOpenURLContext>, onOpen: @escaping (URL) -> Void) -> Bool {
        guard isEnabled else { return false }
        Airbridge.trackDeeplink(openURLContexts: openURLContexts)
        return Airbridge.handleDeeplink(openURLContexts: openURLContexts, onSuccess: onOpen)
    }

    /// 실행 중 — 유니버설 링크.
    static func handle(userActivity: NSUserActivity, onOpen: @escaping (URL) -> Void) -> Bool {
        guard isEnabled else { return false }
        Airbridge.trackDeeplink(userActivity: userActivity)
        return Airbridge.handleDeeplink(userActivity: userActivity, onSuccess: onOpen)
    }

    /// 지연 딥링크 — 앱이 없을 때 트래킹 링크를 눌렀다가 설치 후 첫 실행에서 한 번 받는다.
    ///
    /// 설치 후 첫 호출에서만 동작하고 그 뒤로는 바로 false 를 돌려준다. 저장된 링크가 없거나
    /// 이번 실행이 딥링크로 열렸으면 nil 이 온다(딥링크 쪽이 이미 처리하므로).
    /// 수집이 시작돼야(`startTracking`) 링크를 받아 오므로 TestFlight·심사 빌드에서는 오지 않는다.
    static func handleDeferredDeeplink(onOpen: @escaping (URL) -> Void) {
        guard isEnabled else { return }
        _ = Airbridge.handleDeferredDeeplink { url in
            guard let url else { return }
            onOpen(url)
        }
    }

    // MARK: - ATT

    /// 첫 활성화 때 ATT 프롬프트를 한 번 띄운다.
    ///
    /// `requestTrackingAuthorization` 은 앱이 활성 상태가 아니면 프롬프트 없이 끝나 버리므로,
    /// didFinishLaunching 에서 바로 부르지 않고 첫 didBecomeActive 까지 미룬다.
    /// 이미 응답한 사용자에게는 시스템이 다시 띄우지 않는다.
    private static func requestTrackingAuthorizationOnFirstActive() {
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            ATTrackingManager.requestTrackingAuthorization { _ in }
            if let activeObserver {
                NotificationCenter.default.removeObserver(activeObserver)
                self.activeObserver = nil
            }
        }
    }
}
