import Foundation

// MARK: - Network Protocol (for DI)

public protocol NetworkProviding: Sendable {
    func request<T: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws -> T
}
