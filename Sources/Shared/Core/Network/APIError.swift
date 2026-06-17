import Foundation

// MARK: - Network Error

public enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decoding(Error)
    case network(Error)
    case unauthorized

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "잘못된 URL입니다."
        case .invalidResponse:
            "서버 응답이 올바르지 않습니다."
        case .httpError(let code):
            "서버 오류 (\(code))"
        case .decoding(let error):
            "데이터 처리 오류: \(error.localizedDescription)"
        case .network(let error):
            error.localizedDescription
        case .unauthorized:
            "인증이 필요합니다."
        }
    }
}
