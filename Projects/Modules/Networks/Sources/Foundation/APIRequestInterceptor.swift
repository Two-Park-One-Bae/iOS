//
//  APIRequestInterceptor.swift
//  Networks
//
//  Created by 바견규 on 8/28/26.
//

import Foundation

import Alamofire
import Core

/// 모든 요청의 인증 헤더를 책임진다 — App Check(NM-322) + Bearer(NM-410).
///
/// Alamofire `Session` 은 인터셉터를 **하나만** 받으므로 두 관심사를 한 객체에 합쳤다.
/// 둘 다 Moya 의 동기 `headers` 로는 붙일 수 없다 — App Check 토큰 발급도, Firebase ID 토큰 발급도 async 다.
///
/// - `adapt`: 요청마다 `X-Firebase-AppCheck` + (공개 엔드포인트가 아니면) `Authorization: Bearer`
/// - `retry`: 401 이면 토큰을 **강제 갱신해 한 번만** 재시도하고, 그래도 401 이면 세션 만료로 판정한다
///   (spec: feature/auth/README.md §토큰·세션)
public final class APIRequestInterceptor: RequestInterceptor {

    /// Bearer 를 붙이지 않는 공개 엔드포인트. spec 이 공개로 못박은 셋이 전부다
    /// (spec: domains/auth.md §방식 — "공개 목록은 이 셋뿐").
    ///
    /// Service 별로 플래그를 두는 대신 경로로 판정한다. 인터셉터는 Session 단위라 어느 API 든 여기를 지나고,
    /// 공개 여부는 서버 설정과 1:1로 맞춰야 하는 값이라 한 곳에 문자열로 두는 편이 대조하기 쉽다.
    private static let publicPaths: Set<String> = [
        "/actuator/health",
        "/api/v0/auth/kakao/token",
        "/api/v0/consents",
    ]

    public init() {}

    // MARK: - Adapt

    public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        Task {
            var request = urlRequest

            if let token = await AppCheckService.token() {
                request.setValue(token, forHTTPHeaderField: "X-Firebase-AppCheck")
            } else {
                // 조용히 빠지면 원인 추적이 어렵다 — 디버그 토큰 미등록이 가장 흔한 원인.
                #if DEBUG
                print("⚠️ AppCheck 토큰 없음 — 헤더 생략. 콘솔에 디버그 토큰이 등록됐는지 확인.")
                #endif
            }

            if Self.requiresAuthorization(urlRequest) {
                // 미로그인 상태면 헤더를 생략한다 — 서버가 401 로 답하고, 그 401 은 retry 가 세션 만료로 처리한다.
                // 여기서 에러로 끊으면 Alamofire 가 401 을 만들지 못해 만료 경로가 통째로 사라진다.
                if let idToken = try? await FirebaseAuthService.idToken() {
                    request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                }
            }

            completion(.success(request))
        }
    }

    // MARK: - Retry

    public func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        // 401 만 재시도 대상이다. 503(SERVICE_UNAVAILABLE)은 Firebase·카카오 일시 장애일 수 있어
        // 재시도도 로그아웃도 하지 않는다 — 상위에서 "잠시 후 다시 시도"로 안내한다.
        guard request.response?.statusCode == 401,
              let urlRequest = request.request,
              Self.requiresAuthorization(urlRequest) else {
            completion(.doNotRetry)
            return
        }

        // 같은 401 이라도 **원인이 다르면 처리가 달라야 한다.**
        //
        // `APP_CHECK_FAILED` 는 앱 무결성(App Check) 검증이 막힌 것이라 **사용자 세션과 무관하다.**
        // ID 토큰을 갱신해도 절대 풀리지 않고, 세션 만료로 처리하면 멀쩡히 로그인한 사용자를
        // 로그아웃시킨다 — 실제로 백엔드가 다른 Firebase 프로젝트를 보고 있을 때, 로그인·동의를
        // 마치고 홈에 들어간 직후 아무 안내 없이 로그인 화면으로 튕기는 증상이 났다.
        //
        // 재시도도 하지 않는다. 앱이 고칠 수 있는 게 없으므로 그대로 에러를 올려 화면에서 안내한다.
        guard Self.serverCode(of: request) != "APP_CHECK_FAILED" else {
            completion(.doNotRetry)
            return
        }

        // 이미 한 번 갱신해봤는데 또 401 → 탈퇴·토큰 폐기·공급자 불일치 등 갱신으로 풀 수 없는 상태다.
        guard request.retryCount == 0 else {
            Self.notifySessionExpired()
            completion(.doNotRetryWithError(APIError.tokenReissuanceFailed))
            return
        }

        Task {
            do {
                guard try await FirebaseAuthService.idToken(forceRefresh: true) != nil else {
                    // 로그인 자체가 없는데 인증 API를 부른 상태 — 갱신할 토큰이 없으니 재시도해도 같은 401이다.
                    Self.notifySessionExpired()
                    completion(.doNotRetryWithError(APIError.tokenReissuanceFailed))
                    return
                }
                completion(.retry)
            } catch {
                // 갱신 호출 자체의 실패(네트워크 등)는 세션 만료로 단정하지 않는다 — 다음 요청에서 다시 판정한다.
                completion(.doNotRetryWithError(APIError.tokenReissuanceFailed))
            }
        }
    }

    // MARK: - Private

    /// 공개 목록은 서버 설정과 1:1로 맞춰야 하는 값이라 테스트로 고정한다(internal).
    static func requiresAuthorization(_ request: URLRequest) -> Bool {
        guard let path = request.url?.path else { return true }
        return !publicPaths.contains(path)
    }

    /// 응답 본문(RFC 9457)의 `code`. 같은 401 의 원인을 가르는 데 쓴다.
    ///
    /// 본문은 이미 받아 둔 것이라 여기서 네트워크를 더 타지 않는다. 디코딩에 실패하면 `nil` —
    /// 원인을 모르는 401 은 기존 경로(갱신 1회 → 세션 만료)로 보낸다.
    private static func serverCode(of request: Request) -> String? {
        guard let data = (request as? DataRequest)?.data else { return nil }
        return try? JSONDecoder().decode(NetworkError.self, from: data).code
    }

    private static func notifySessionExpired() {
        // 화면 전환을 유발하는 신호라 메인에서 던진다.
        Task { @MainActor in
            NotificationCenter.default.post(name: .authSessionExpired, object: nil)
        }
    }
}
