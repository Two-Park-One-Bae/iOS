import Foundation

// MARK: - API Endpoint

public struct APIEndpoint: Sendable {
    public enum HTTPMethod: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
    }

    public let baseURL: String
    public let path: String
    public let method: HTTPMethod
    public let headers: [String: String]
    public let queryItems: [URLQueryItem]
    public let body: Data?

    public var url: URL? {
        var components = URLComponents(string: baseURL)
        components?.path = path
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        return components?.url
    }

    public var urlRequest: URLRequest? {
        guard let url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    public static func get(
        baseURL: String = "https://api.example.com",
        path: String,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:]
    ) -> APIEndpoint {
        APIEndpoint(
            baseURL: baseURL,
            path: path,
            method: .get,
            headers: headers,
            queryItems: queryItems,
            body: nil
        )
    }

    public static func post(
        baseURL: String = "https://api.example.com",
        path: String,
        body: Data? = nil,
        headers: [String: String] = [:]
    ) -> APIEndpoint {
        APIEndpoint(
            baseURL: baseURL,
            path: path,
            method: .post,
            headers: headers,
            queryItems: [],
            body: body
        )
    }
}
