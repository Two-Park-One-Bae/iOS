//
//  Error.swift
//  Networks
//
//  Created by 바견규 on 7/2/26.
//

public struct NetworkError: Decodable, Error {
    public let type: String
    public let title: String
    public let status: Int
    public let detail: String
    public let instance: String?
    public let code: String?
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
