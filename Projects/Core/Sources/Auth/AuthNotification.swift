//
//  AuthNotification.swift
//  Core
//
//  Created by 바견규 on 8/28/26.
//

import Foundation

public extension Notification.Name {

    /// 토큰 강제 갱신 후에도 401 — 세션 만료(탈퇴·폐기 포함)로 보고 로그인 화면으로 유도한다.
    ///
    /// 네트워크 인터셉터(Networks)가 던지고 앱 화면 전환(App)이 받는다. 둘은 서로를 참조할 수 없는
    /// 방향이라 NotificationCenter 로 잇는다.
    ///
    /// **503 은 여기 해당하지 않는다.** Firebase·카카오 일시 장애일 수 있어 세션을 유지한다
    /// (spec: feature/auth/README.md §토큰·세션).
    ///
    /// - Note: 짝이 되는 `.authDidSignOut` 은 Domain 에 있다 — Domain 이 Core 를 참조하지 않도록
    ///   각 신호를 **던지는 모듈**에 두었다.
    static let authSessionExpired = Notification.Name("nursemate.auth.sessionExpired")
}
