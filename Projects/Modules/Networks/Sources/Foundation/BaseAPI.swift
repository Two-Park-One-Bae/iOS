//
//  BaseAPI.swift
//  Networks
//
//  Created by 바견규 on 7/2/26.
//

import Foundation
import Moya

public enum APIType {
    case auth    // 인증/계정
    case pill    // 알약 인식
    case rag     // 임상 지식 검색 (V1)
    case timer   // 처치 타이머
}

public protocol BaseAPI: TargetType, AccessTokenAuthorizable {
    static var apiType: APIType { get }
}

public extension BaseAPI {
    var baseURL: URL {
        var base = NetworkConfig.baseURL

        // 인증 엔드포인트도 전부 /api/v0 아래에 있다 (spec: openapi.yaml).
        // 루트 경로는 헬스 체크(/actuator/health)뿐이고 앱이 호출하지 않는다.
        switch Self.apiType {
        case .auth, .pill, .rag, .timer: base += "/api/v0"
        }

        guard let url = URL(string: base) else {
            fatalError("baseURL을 구성할 수 없습니다.")
        }
        return url
    }

    var headers: [String: String]? {
        ["Content-Type": "application/json"]
    }

    // 401만 Alamofire 검증 실패로 떨어뜨려 APIRequestInterceptor.retry 가 잡게 한다.
    // (토큰 강제 갱신 후 1회 재시도 — spec: feature/auth/README.md §토큰·세션)
    // 나머지 상태코드는 통과시켜 BaseService 가 ProblemDetail 로 직접 분기한다.
    var validationType: ValidationType {
        .customCodes(Array(200..<600).filter { $0 != 401 })
    }

    // Moya 의 AccessTokenPlugin 은 쓰지 않는다 — 토큰 제공이 동기라서 async 인 Firebase ID 토큰 발급을 담을 수 없다.
    // Authorization 헤더는 APIRequestInterceptor.adapt 가 붙인다.
    var authorizationType: AuthorizationType? { .bearer }
}
