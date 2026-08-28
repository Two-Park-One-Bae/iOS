//
//  AuthNotification.swift
//  Domain
//
//  Created by 바견규 on 8/28/26.
//

import Foundation

public extension Notification.Name {

    /// 로그아웃·탈퇴가 실제로 끝났다. 계정에 딸린 캐시(잔여 횟수 등)를 전부 버리는 신호.
    ///
    /// `AuthUseCase` 가 던지고 조립 지점(App)이 받아 다른 UseCase 의 캐시를 지운다 —
    /// Domain 안에서 UseCase 끼리 직접 참조하지 않기 위해서다.
    /// 병동 공용 기기에서 앞사람의 잔여 횟수·동의 상태가 다음 사람에게 보이면 안 된다
    /// (spec: feature/auth/README.md §계정 스코프 캐시 폐기).
    ///
    /// - Note: 짝이 되는 `.authSessionExpired` 는 Core 에 있다(Networks 인터셉터가 던진다).
    static let authDidSignOut = Notification.Name("nursemate.auth.didSignOut")
}
