//
//  GoogleSignInService.swift
//  Core
//
//  Created by 바견규 on 8/28/26.
//

import UIKit

import GoogleSignIn

/// 구글 로그인 SDK 래퍼 (NM-410).
///
/// **왜 Core 에 있나** — GoogleSignIn 은 AppCheckCore·FBLPromises·GTMSessionFetcher·GoogleUtilities 를
/// 정적으로 끌고 오는데, 이건 Core 가 Firebase 로 이미 링크하고 있는 것들과 같다.
/// 상위 모듈(Data)에서 링크하면 같은 ObjC 클래스가 Core.framework 와 앱 바이너리에 두 벌 올라가
/// 런타임에 엉뚱한 구현이 잡힌다(`-[FBLPromise HTTPResponse]: unrecognized selector` 로 즉시 크래시).
/// Firebase 를 이미 들고 있는 Core 한 곳에서만 링크해 사본을 하나로 유지한다.
public enum GoogleSignInService {

    /// 사용자가 로그인 시트를 닫은 경우. 오류 안내를 띄우지 않도록 상위에서 따로 구분한다.
    public struct CancelledError: Error {
        public init() {}
    }

    /// 설정 누락(Firebase 콘솔에서 Google 공급자 미활성)·토큰 부재 등.
    public struct UnavailableError: Error {
        public init() {}
    }

    /// `FirebaseApp.configure()` **이후에** 호출한다 — clientID 를 Firebase 옵션에서 읽는다.
    ///
    /// 콘솔에서 Google 공급자를 켜야 `GoogleService-Info.plist` 에 `CLIENT_ID` 가 생긴다.
    /// 없으면 조용히 넘어가고 구글 버튼만 런타임에 실패한다 — 다른 공급자는 정상 동작한다.
    public static func configure() {
        guard let clientID = FirebaseService.googleClientID else {
            #if DEBUG
            print("⚠️ GoogleService-Info.plist 에 CLIENT_ID 가 없다 — Firebase 콘솔에서 Google 로그인을 켜고 plist 를 다시 받을 것.")
            #endif
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }

    /// 로그인 후 앱으로 돌아오는 URL 을 처리했으면 true.
    public static func handle(url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    /// 구글 로그인 시트를 띄우고, 그 결과로 Firebase 에 로그인한다.
    @MainActor
    public static func signIn(presenting presenter: UIViewController) async throws {
        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        } catch let error as GIDSignInError where error.code == .canceled {
            throw CancelledError()
        } catch {
            throw UnavailableError()
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw UnavailableError()
        }

        try await FirebaseAuthService.signInWithGoogle(
            idToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
    }
}
