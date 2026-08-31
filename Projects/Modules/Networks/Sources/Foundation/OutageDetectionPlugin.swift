//
//  OutageDetectionPlugin.swift
//  Networks
//
//  Created by 바견규 on 9/1/26.
//

import Foundation

import Core
import Moya

/// 서버 장애 징후가 보이면 Remote Config 를 즉시 확인하게 만든다 (NM-423).
///
/// **점검 화면을 띄우는 신호를 어디서 받을 것인가**의 답이다. 후보가 둘 있었다.
///
///  1. 백엔드가 점검 응답(503 + `MAINTENANCE_MODE`)을 내려준다.
///  2. Remote Config 에 플래그를 두고 앱이 읽는다.
///
/// 1번은 **서버가 살아 있어야만** 쓸 수 있다. 정작 서버가 죽은 진짜 장애 때는 타임아웃이거나
/// 로드밸런서의 HTML 502 라서 아무 신호도 못 준다. 그래서 2번이 필요하다 — Remote Config 는
/// 구글이 호스팅하므로 우리 백엔드와 독립이다.
///
/// 문제는 2번의 반영 속도였다. 실시간 리스너는 실측 결과 최악 약 4분이고
/// [SDK 결함](https://github.com/firebase/firebase-ios-sdk/issues/15490)으로 아예 멈추기도 한다.
/// 그렇다고 주기적으로 폴링하면 Firebase 가 권장하는 fetch 간격(12시간)을 어기게 된다.
///
/// **그래서 시간이 아니라 실패를 트리거로 삼는다.** 서버가 죽으면 그 사실을 앱이 가장 먼저
/// 안다 — 요청이 실패하기 시작한다. 평상시엔 아무 비용도 들지 않고, 실제로 문제가 생긴
/// 순간에만 캐시를 무시하고 설정을 받아온다.
///
/// 디바운스는 `RemoteConfigService.checkForOutage()` 쪽에 있다. 요청이 무더기로 실패해도
/// fetch 는 분당 한 번을 넘지 않는다.
public struct OutageDetectionPlugin: PluginType {

    public init() {}

    public func didReceive(_ result: Result<Response, MoyaError>, target: TargetType) {
        guard Self.looksLikeOutage(result) else { return }
        RemoteConfigService.shared.checkForOutage()
    }

    /// 서버가 죽었을 때 나타나는 신호인가.
    ///
    /// **4xx 는 포함하지 않는다.** 요청이 잘못됐거나 인증이 만료된 것은 서버가 멀쩡하다는
    /// 뜻이라, 여기서 걸면 평상시에도 계속 fetch 를 날리게 된다.
    private static func looksLikeOutage(_ result: Result<Response, MoyaError>) -> Bool {
        switch result {
        case .success(let response):
            return (500...599).contains(response.statusCode)

        case .failure(let error):
            // 상태코드가 있으면 그것으로 판단한다(검증 실패로 .failure 가 된 5xx).
            if let statusCode = error.response?.statusCode {
                return (500...599).contains(statusCode)
            }
            // 응답 자체가 없는 경우 — 연결이 안 되거나 끊긴 것. 전송 계층 오류만 본다.
            guard let urlError = error.underlyingURLError else { return false }
            return outageIndicating.contains(urlError.code)
        }
    }

    /// 서버 도달 실패로 볼 수 있는 `URLError`.
    ///
    /// `.notConnectedToInternet` 은 뺐다. 기기에 네트워크가 없다는 뜻이라 Remote Config
    /// 요청도 어차피 실패한다 — 확인해봐야 소용이 없다. `.cancelled` 도 화면 이탈 등으로
    /// 흔히 발생하므로 장애 신호가 아니다.
    private static let outageIndicating: Set<URLError.Code> = [
        .timedOut,
        .cannotConnectToHost,
        .cannotFindHost,
        .networkConnectionLost,
        .badServerResponse,
        .dnsLookupFailed,
    ]
}

private extension MoyaError {

    /// `MoyaError` → `AFError` → `URLError` 로 감싸여 오므로 역으로 풀어낸다.
    var underlyingURLError: URLError? {
        var current: Error? = self
        while let error = current {
            if let urlError = error as? URLError { return urlError }
            current = (error as NSError).userInfo[NSUnderlyingErrorKey] as? Error
        }
        return nil
    }
}
