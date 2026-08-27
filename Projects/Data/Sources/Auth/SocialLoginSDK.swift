//
//  SocialLoginSDK.swift
//  Data
//
//  Created by 바견규 on 8/28/26.
//

import Foundation
import UIKit

import Core
import KakaoSDKAuth
import KakaoSDKCommon

/// 소셜 로그인 SDK 초기화·URL 콜백 (NM-410).
///
/// 두 SDK 모두 "앱 밖(사파리·카카오톡)에 다녀와서 URL 로 돌아온다"는 같은 모양이라 한 곳에 모았다.
/// 공급자 구현(`GoogleSignInProvider` 등)과 같은 모듈에 둬서, App 이 소셜 SDK 를 직접 링크하지 않아도 된다.
public enum SocialLoginSDK {

    /// `FirebaseApp.configure()` **이후에** 호출한다 — 구글 clientID 를 Firebase 옵션에서 읽어온다.
    public static func configure() {
        GoogleSignInService.configure()
        configureKakao()
    }

    /// 로그인 후 앱으로 돌아오는 URL 을 처리했으면 true.
    ///
    /// 처리하지 못한 URL 은 false 로 돌려보내 기존 딥링크 라우팅(`nursemate://`)이 이어받게 한다.
    ///
    /// 카카오 SDK 의 URL 핸들러가 메인 액터 격리라 이 메서드도 함께 격리한다 — 어차피 호출부는 SceneDelegate 다.
    @MainActor
    public static func handle(url: URL) -> Bool {
        if AuthApi.isKakaoTalkLoginUrl(url) {
            return AuthController.handleOpenUrl(url: url)
        }
        return GoogleSignInService.handle(url: url)
    }

    // MARK: - Private

    private static func configureKakao() {
        guard let appKey = Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String,
              !appKey.isEmpty else {
            #if DEBUG
            print("⚠️ KAKAO_NATIVE_APP_KEY 가 비어 있다 — XCConfig/Secrets.xcconfig 에 네이티브 앱 키를 넣을 것.")
            #endif
            return
        }
        KakaoSDK.initSDK(appKey: appKey)
    }
}
