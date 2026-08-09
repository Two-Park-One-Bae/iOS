//
//  AppCheckService.swift
//  Core
//
//  Created by 바견규 on 7/21/26.
//

import Foundation

import FirebaseAppCheck
import FirebaseCore

/// Firebase App Check — "정상 앱에서 온 요청인가"를 서버가 검증할 수 있게 토큰을 발급한다 (NM-322).
///
/// 식별 한도는 기기별 카운트라, 토큰 없이 device_id만 쓰면 스크립트로 UUID를 대량 생성해
/// 한도를 무한정 늘릴 수 있다(farming). App Check가 그 우회를 막는 몫이고,
/// Keychain UUID는 재설치 생존을 맡는다 — 둘이 서로의 구멍을 메운다.
public enum AppCheckService {

    /// **반드시 `FirebaseApp.configure()` 이전에 호출해야 한다.** 이후에 부르면 팩토리가 무시된다.
    ///
    /// 개발 빌드(DEBUG, 시뮬·실기기 공통)는 디버그 프로바이더, 릴리즈(TestFlight·App Store)는 App Attest.
    ///
    /// "실기기면 App Attest"로 나누지 **않는** 이유: Xcode에서 올린 개발 서명 빌드는 App Attest를
    /// **sandbox 환경**으로 어테스트하는데, Firebase App Check는 sandbox 토큰을 받지 않는다
    /// (공식 문서: "App Check currently doesn't accept tokens generated in the App Attest sandbox
    /// environment"). 그래서 개발 중엔 실기기여도 App Attest가 403(App attestation failed)로 실패하고,
    /// Firebase 권장대로 디버그 프로바이더를 써야 한다. 실제 App Attest 경로는 production 배포에서만 검증된다.
    public static func configure() {
        #if DEBUG
        // 개발 빌드(시뮬·실기기): 디버그 프로바이더.
        // 콘솔 로그에 찍히는 디버그 토큰을 Firebase Console(App Check → 앱 → 디버그 토큰 관리)에
        // 등록해야 검증을 통과한다. 토큰은 앱 데이터에 저장돼 리빌드엔 유지되고,
        // 앱 삭제·시뮬 초기화·새 기기일 때만 새로 생성된다(그때 뜬 토큰을 추가 등록; 여러 개 등록 가능).
        // 매번 재생성되는 걸 막으려면 스킴 환경변수 `FIRAAppCheckDebugToken`에 고정 UUID를 넣는다.
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        // 릴리즈(TestFlight·App Store = App Attest production 환경): App Attest.
        // Firebase는 App Attest용 팩토리를 기본 제공하지 않아 커스텀 팩토리로 감싼다(파일 하단 참고).
        AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
        #endif
    }

    /// 현재 App Check 토큰. 실패하면 nil.
    ///
    /// 실패를 요청 실패로 올리지 않는다 — 네트워크 순간 오류로 앱 전체 기능이 멈추는 게 더 나쁘다.
    /// 다만 서버가 App Check를 **강제(enforce)**하므로, 토큰이 없으면 서버가 401(APP_CHECK_FAILED)로
    /// 거절한다. 디버그에서 401이면 콘솔 로그의 디버그 토큰이 등록됐는지부터 확인.
    public static func token() async -> String? {
        do {
            return try await AppCheck.appCheck().token(forcingRefresh: false).token
        } catch {
            // 실패 자체는 요청 실패로 올리지 않지만(위 주석), 원인 추적을 위해 디버그에선 실제 에러를 남긴다.
            // 실기기 App Attest 실패(콘솔 미설정·환경 불일치 등)와 시뮬 디버그 토큰 미등록을 여기서 구분한다.
            #if DEBUG
            print("⚠️ AppCheck token() 실패: \(error)")
            #endif
            return nil
        }
    }
}

/// App Attest 프로바이더 팩토리.
///
/// Firebase는 `AppCheckDebugProviderFactory`·`DeviceCheckProviderFactory`만 기본 제공하고,
/// **App Attest용 팩토리는 제공하지 않는다.** 프로바이더 타입(`AppAttestProvider`)만 있으므로
/// `AppCheckProviderFactory`를 직접 구현해 `AppAttestProvider(app:)`를 감싼다.
///
/// App Attest는 Secure Enclave가 필요해 시뮬레이터에선 런타임에 토큰 발급이 실패한다 —
/// 그래서 이 팩토리는 실기기에서만 설정된다(`AppCheckService.configure()` 참고).
private final class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        AppAttestProvider(app: app)
    }
}
