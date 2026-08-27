//
//  SocialSignInProviding.swift
//  Data
//
//  Created by 바견규 on 8/28/26.
//

import UIKit

/// 공급자 하나의 "로그인 성공 = Firebase 세션이 생겼다" 까지를 책임진다.
///
/// 구글·애플은 Firebase 네이티브라 SDK → credential → Firebase 로 끝나고,
/// 카카오는 중간에 서버 교환(POST /auth/kakao/token)이 하나 더 낀다.
/// 그 차이를 이 프로토콜 뒤에 숨겨서, Repository 는 세 공급자를 같은 모양으로 다룬다.
protocol SocialSignInProviding {
    /// 실패 시 `AuthError` 로 던진다. 사용자가 시트를 닫았으면 `.cancelled`.
    func signIn() async throws
}

/// 소셜 SDK 는 모달을 띄울 뷰컨트롤러를 요구한다. 화면 계층을 모르는 Data 가 최상단을 직접 찾는다.
///
/// `DSAlertCardView.presentOverWindow` 와 같은 방식 — 이미 모달이 떠 있어도 그 위에 뜨도록
/// presentedViewController 체인을 끝까지 탄다.
@MainActor
enum PresentationAnchor {

    static func topMostViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }

        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
