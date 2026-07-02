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

        switch Self.apiType {
        case .auth: break  // /health 등 루트
        case .pill, .rag, .timer: base += "/api/v0"
        }

        guard let url = URL(string: base) else {
            fatalError("baseURL을 구성할 수 없습니다.")
        }
        return url
    }

    var headers: [String: String]? {
        ["Content-Type": "application/json"]
    }

    // 401은 ReissueInterceptor가 처리하므로 Moya 성공으로 통과시킴
    var validationType: ValidationType {
        .customCodes(Array(200..<600).filter { $0 != 401 })
    }

    var authorizationType: AuthorizationType? { .bearer }
}
