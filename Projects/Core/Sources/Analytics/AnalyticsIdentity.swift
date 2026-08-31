//
//  AnalyticsIdentity.swift
//  Core
//

import Foundation

import FirebaseAuth

/// 지표·크래시의 **사용자 식별자**를 로그인 상태에 맞춰 유지한다 (NM-410 이후).
///
/// ## 왜 한 곳에 모았나
///
/// 붙여야 하는 시점이 셋(앱 시작·로그인 성공·로그아웃)인데, 각 호출부에 흩어 놓으면
/// 한 곳만 빠뜨려도 **이전 사용자에게 이벤트가 붙는다**. `addStateDidChangeListener` 는
/// 그 셋을 모두 같은 콜백으로 주므로 빠뜨릴 자리가 없다 — 앱 시작 시 세션 복원까지 포함해서.
///
/// ## 왜 Firebase UID 인가
///
/// 예전엔 Keychain UUID(`DeviceIdentifier`)를 썼다. 재설치를 견디려는 선택이었지만
/// **사람이 아니라 기기를 센다** — 한 사람이 두 기기를 쓰면 둘, 기기를 바꾸면 신규다.
/// 북극성 짝지표가 "주간 케어 활성 **간호사 수**"라 그 차이가 곧 지표 오차다.
///
/// 서버도 회원을 Firebase UID 로 저장하므로(`AppUserEntity.userId`), 이 값 하나로
/// 지표·크래시·서버 로그가 이어진다. 기기 UUID 는 서버가 `X-Device-Id` 를 폐기하면서
/// (NM-410 클린 컷오버) 서버와의 연결이 이미 끊겨 있었다.
///
/// ## 로그인 전에는 붙이지 않는다
///
/// 로그인은 건너뛸 수 없는 단계라(`AppCoordinator`) 로그인 전 이벤트는 로그인 화면뿐이다.
/// 여기서 기기 UUID 를 넣었다가 로그인 시 UID 로 바꾸면 GA4(Blended)가 **같은 설치를 두
/// 사용자로 센다** — 얻을 게 없는 자리에서 지표만 부풀린다.
public enum AnalyticsIdentity {

    private static var handle: AuthStateDidChangeListenerHandle?

    /// - Parameter includeAmplitude: 내부 빌드에서는 Amplitude 수집을 끄므로 `false`.
    ///   Crashlytics·GA4 는 dev 프로젝트로 분리돼 있어 내부에서도 붙인다.
    public static func start(includeAmplitude: Bool) {
        guard handle == nil else { return }
        handle = Auth.auth().addStateDidChangeListener { _, user in
            apply(uid: user?.uid, includeAmplitude: includeAmplitude)
        }
    }

    private static func apply(uid: String?, includeAmplitude: Bool) {
        if let uid {
            FirebaseService.setUserID(uid)
            if includeAmplitude { AmplitudeService.setUserID(uid) }
        } else {
            FirebaseService.clearUserID()
            if includeAmplitude { AmplitudeService.clearUserID() }
        }
    }
}
