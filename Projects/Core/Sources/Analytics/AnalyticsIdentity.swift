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
            apply(uid: user?.uid, email: user.flatMap(signInEmail), includeAmplitude: includeAmplitude)
        }
    }

    private static func apply(uid: String?, email: String?, includeAmplitude: Bool) {
        if let uid {
            FirebaseService.setUserID(uid)
            if includeAmplitude { AmplitudeService.setUserID(uid) }
        } else {
            FirebaseService.clearUserID()
            if includeAmplitude { AmplitudeService.clearUserID() }
        }

        // 로그아웃 상태에서는 값을 지운다. 남겨 두면 다음 사용자에게 이전 사람의 꼬리표가 붙는다.
        let flag = uid == nil ? nil : String(isTestAccount(email))
        FirebaseService.setUserProperty(flag, forName: testAccountProperty)
        if includeAmplitude, let flag {
            AmplitudeService.identify(key: testAccountProperty, value: flag)
        }
    }

    /// 로그인에 쓰인 이메일.
    ///
    /// **최상위 `user.email` 만 보면 안 된다.** 페더레이션 전용 계정(구글·애플)은 그 필드가
    /// 비어 있고 이메일이 `providerData` 안에만 들어오는 경우가 있다 — Firebase 콘솔에는
    /// 이메일이 멀쩡히 보여서 눈으로는 안 잡힌다. 실제로 구글 로그인 계정에서
    /// `email=nil`, `providerData=[google.com=…]` 인 것을 확인했고, 그래서
    /// `is_test_account` 가 어떤 계정에서도 `true` 가 되지 않았다.
    ///
    /// 카카오(커스텀 토큰)는 공급자 정보에도 이메일이 없을 수 있다 — 그 경우는 nil 이 맞고,
    /// 판별은 서버가 내려주는 회원 정보로 옮겨야 한다(별도 과제).
    private static func signInEmail(_ user: User) -> String? {
        user.email ?? user.providerData.compactMap(\.email).first
    }

    // MARK: - 심사·QA 계정 표시

    /// 앱 심사자와 QA 가 만든 지표를 분석에서 걸러내기 위한 사용자 속성.
    ///
    /// **수집을 끄지 않고 꼬리표만 붙인다.** 끄는 방식은 두 가지로 실패한다 — `first_open` 은
    /// `FirebaseApp.configure()` 시점에 나가므로 로그인 전에 이미 늦고, 잘못 걸러 실사용자를
    /// 막으면 그 데이터는 되돌릴 수 없다. 값을 남겨 두면 판단을 나중에 바꿀 수 있다.
    ///
    /// 심사자는 애플에 제공한 계정으로 로그인하므로 로그인 이후 이벤트는 이 값으로 갈린다.
    /// 로그인 전 이벤트(로그인 화면)는 GA4 의 국가 측정기준으로 거른다 — 심사는 미국에서 돈다.
    private static let testAccountProperty = "is_test_account"

    /// 기본 목록. Remote Config `test_account_emails`(콤마 구분)로 덮어쓸 수 있다 —
    /// 애플이 다른 계정을 요구하거나 QA 계정이 늘어도 **배포 없이** 바꾸기 위해서다.
    ///
    /// 앱 시작 직후에는 Remote Config fetch 가 아직 안 끝났을 수 있어 이 기본값이 쓰인다.
    /// 심사 계정은 여기 들어 있으므로 그 경우에도 판별된다.
    private static let defaultTestAccounts = ["nursematetest@gmail.com"]

    private static func isTestAccount(_ email: String?) -> Bool {
        guard let email = email?.lowercased() else { return false }
        let configured = RemoteConfigService.shared.string("test_account_emails")
        let list = configured.isEmpty
            ? defaultTestAccounts
            : configured.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces).lowercased()
            }
        return list.contains(email)
    }
}
