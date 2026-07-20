//
//  Error.swift
//  Networks
//
//  Created by 바견규 on 7/2/26.
//

import Foundation

public struct NetworkError: Decodable, Error {
    public let type: String
    public let title: String
    public let status: Int
    public let detail: String
    public let instance: String?
    public let code: String?

    /// 응답 원문. RFC 9457은 표준 필드 외 **확장 멤버**를 허용하는데(예: 429 LIMIT_EXCEEDED의 `usage`),
    /// 도메인별 확장 필드를 이 Foundation 타입이 알 필요는 없으므로 원문만 들고 있다가
    /// 필요한 계층(Repository)에서 직접 decode 한다. 디코딩 대상이 아니라 decode 후 주입한다.
    public var rawBody: Data?

    enum CodingKeys: String, CodingKey {
        case type, title, status, detail, instance, code
    }
}

public enum APIError: Error, Equatable {
    case network(statusCode: Int, error: NetworkError)
    case unknown
    case tokenReissuanceFailed

    public static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown):                             return true
        case (.tokenReissuanceFailed, .tokenReissuanceFailed): return true
        case (.network(let ls, _), .network(let rs, _)):       return ls == rs
        default:                                               return false
        }
    }
}
