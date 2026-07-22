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
    public static func configure() {
        #if DEBUG
        // 시뮬레이터·디버그 빌드는 App Attest를 쓸 수 없어 디버그 프로바이더를 쓴다.
        // 콘솔 로그에 찍히는 디버그 토큰을 Firebase Console(App Check → 앱 → 디버그 토큰 관리)에
        // 등록해야 검증을 통과한다. 토큰은 앱 데이터에 저장돼 리빌드엔 유지되고,
        // 앱 삭제·시뮬 초기화·새 기기일 때만 새로 생성된다(그때 뜬 토큰을 추가 등록; 여러 개 등록 가능).
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
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
            return nil
        }
    }
}
