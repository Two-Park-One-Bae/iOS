//
//  AppCheckInterceptor.swift
//  Networks
//
//  Created by 바견규 on 7/21/26.
//

import Foundation

import Alamofire
import Core

/// 모든 요청에 `X-Firebase-AppCheck` 토큰을 붙인다 (NM-322).
///
/// Moya의 `headers`는 동기라서 여기서 처리한다 — App Check 토큰 발급이 async이기 때문.
/// 토큰 발급에 실패하면 헤더 없이 그대로 보낸다. 통과 여부 판정은 서버 몫이고,
/// 콘솔 미설정 같은 이유로 앱이 통째로 멈추는 걸 피한다.
public final class AppCheckInterceptor: RequestInterceptor {

    public init() {}

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
            completion(.success(request))
        }
    }
}
