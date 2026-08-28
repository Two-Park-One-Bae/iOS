//
//  GoogleSignInProvider.swift
//  Data
//
//  Created by 바견규 on 8/28/26.
//

import UIKit

import Core
import Domain

/// 구글 로그인 — Firebase 네이티브 공급자.
///
/// SDK 호출 자체는 `Core.GoogleSignInService` 가 한다(중복 링크 문제로 Core 만 GoogleSignIn 을 링크한다).
/// 여기서는 화면을 찾아 넘기고, Core 의 에러를 도메인 에러로 옮기는 일만 한다.
struct GoogleSignInProvider: SocialSignInProviding {

    func signIn() async throws {
        guard let presenter = await PresentationAnchor.topMostViewController() else {
            throw AuthError.unknown
        }

        do {
            try await GoogleSignInService.signIn(presenting: presenter)
        } catch is GoogleSignInService.CancelledError {
            // 사용자가 시트를 닫은 것 — 오류 안내를 띄우지 않는다.
            throw AuthError.cancelled
        } catch is GoogleSignInService.UnavailableError {
            throw AuthError.unknown
        }
    }
}
