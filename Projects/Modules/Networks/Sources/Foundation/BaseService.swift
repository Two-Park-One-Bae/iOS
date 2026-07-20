//
//  BaseService.swift
//  Networks
//
//  Created by 바견규 on 7/2/26.
//

import Combine
import Foundation

import Alamofire
import Moya

// 모든 Service 클래스의 베이스. Target은 TargetType을 채택한 API enum
// 제네릭으로 선언해서 PillService<PillAPI>, HomeService<HomeAPI> 식으로 재사용
open class BaseService<Target: TargetType> {

    // 외부에서는 API로 쓰고 내부에서는 Target과 동일하게 취급
    typealias API = Target

    // Alamofire RequestInterceptor: 토큰 갱신(retry) 로직을 담당
    private let interceptor: RequestInterceptor?

    // Moya 플러그인 목록: 로깅, AccessToken 주입 등
    private let plugins: [PluginType]

    // 실제 네트워크 요청을 보내는 Moya 프로바이더. lazy로 선언해 첫 접근 시점에 생성
    private lazy var defaultProvider: MoyaProvider<API> = {
        let configuration = URLSessionConfiguration.default
        // 응답 대기(패킷 간) 타임아웃. pill-attributes는 서버측 Gemini 추출로 수십 초 걸림.
        configuration.timeoutIntervalForRequest = 60
        // 이미지 업로드 + AI 처리 전체를 커버하는 리소스 타임아웃.
        configuration.timeoutIntervalForResource = 120
        // 캐시 무시: 항상 서버에서 최신 데이터를 받아옴
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        // Alamofire Session에 interceptor를 주입해서 401 발생 시 토큰 갱신 후 재시도
        let session = Session(
            configuration: configuration,
            interceptor: interceptor
        )

        return MoyaProvider<API>(
            session: session,
            plugins: plugins
        )
    }()

    // 테스트 시 provider를 stub으로 교체할 수 있도록 internal 접근
    lazy var provider = defaultProvider

    public init(plugins: [PluginType], interceptor: RequestInterceptor? = nil) {
        self.plugins = plugins
        self.interceptor = interceptor
    }
}

// MARK: - Request Methods

extension BaseService {

    /// 성공 응답 바디를 T로 decode. 상태 코드 분기 없이 decode 실패만 에러 처리
    /// - 사용처: 에러 응답을 별도로 핸들링하지 않아도 되는 단순 요청
    func requestObjectInCombine<T: Decodable>(_ target: API) -> AnyPublisher<T, Error> {
        // Future: 단일 값 또는 에러를 비동기로 방출하는 Publisher
        Future { promise in
            self.provider.request(target) { response in
                switch response {
                case .success(let value):
                    do {
                        // value.data: 서버 응답 바디 Data. T 타입으로 JSON decode
                        let body = try JSONDecoder().decode(T.self, from: value.data)
                        promise(.success(body))
                    } catch {
                        // JSON 구조가 T와 맞지 않으면 decode 에러
                        promise(.failure(error))
                    }
                case .failure(let error):
                    // Interceptor가 토큰 재발급에 실패한 경우 tokenReissuanceFailed로 전파
                    // 패턴 매칭으로 에러 체인을 역으로 추적: MoyaError → AFError → APIError
                    if case MoyaError.underlying(let error, _) = error,
                       case AFError.requestRetryFailed(let retryError, _) = error,
                       let retryError = retryError as? APIError,
                       retryError == .tokenReissuanceFailed {
                        promise(.failure(retryError))
                    } else {
                        promise(.failure(error))
                    }
                }
            }
        }.eraseToAnyPublisher() // Future<T, Error> → AnyPublisher<T, Error> 타입 지우기
    }

    /// 4xx/5xx를 NetworkError(RFC 9457)로 decode해서 APIError.network로 throw
    /// - 사용처: 에러 코드(code)나 detail 메시지를 UI에 직접 보여줘야 하는 요청
    func requestObjectWithNetworkErrorInCombine<T: Decodable>(_ target: API) -> AnyPublisher<T, Error> {
        Future { promise in
            self.provider.request(target) { response in
                switch response {
                case .success(let value):
                    do {
                        // validationType에서 401을 통과시켰으므로 여기서 statusCode 직접 분기
                        guard let httpResponse = value.response else {
                            throw APIError.unknown
                        }

                        switch httpResponse.statusCode {
                        case 200...399:
                            // 정상 응답: 바디를 T로 decode
                            let body = try JSONDecoder().decode(T.self, from: value.data)
                            promise(.success(body))
                        case 400...599:
                            // 에러 응답: 서버가 RFC 9457 형식으로 내려주는 ProblemDetail decode
                            var problem = try JSONDecoder().decode(NetworkError.self, from: value.data)
                            // 확장 멤버(예: 429의 usage)를 상위 계층이 decode할 수 있도록 원문 보존
                            problem.rawBody = value.data
                            // statusCode와 함께 APIError.network로 래핑해서 throw
                            throw APIError.network(statusCode: httpResponse.statusCode, error: problem)
                        default:
                            throw APIError.unknown
                        }
                    } catch {
                        promise(.failure(error))
                    }
                case .failure(let error):
                    if case MoyaError.underlying(let error, _) = error,
                       case AFError.requestRetryFailed(let retryError, _) = error,
                       let retryError = retryError as? APIError,
                       retryError == .tokenReissuanceFailed {
                        promise(.failure(retryError))
                    } else {
                        promise(.failure(error))
                    }
                }
            }
        }.eraseToAnyPublisher()
    }

    /// async/await 방식. Combine 대신 Swift Concurrency를 쓸 때 사용
    /// - withUnsafeThrowingContinuation: 콜백 기반 API를 async throws로 브리징
    func requestObjectAsync<T: Decodable>(_ target: API) async throws -> T {
        try await withUnsafeThrowingContinuation { continuation in
            self.provider.request(target) { response in
                switch response {
                case .success(let value):
                    do {
                        guard let httpResponse = value.response else {
                            throw APIError.unknown
                        }

                        switch httpResponse.statusCode {
                        case 200...399:
                            let body = try JSONDecoder().decode(T.self, from: value.data)
                            // continuation.resume: async 컨텍스트로 값을 돌려줌
                            continuation.resume(returning: body)
                        case 400...599:
                            var problem = try JSONDecoder().decode(NetworkError.self, from: value.data)
                            problem.rawBody = value.data
                            continuation.resume(throwing: APIError.network(statusCode: httpResponse.statusCode, error: problem))
                        default:
                            continuation.resume(throwing: APIError.unknown)
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    if case MoyaError.underlying(let error, _) = error,
                       case AFError.requestRetryFailed(let retryError, _) = error,
                       let retryError = retryError as? APIError,
                       retryError == .tokenReissuanceFailed {
                        continuation.resume(throwing: retryError)
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    /// 응답 바디가 없는 요청 (DELETE 등). statusCode만 반환
    func requestObjectInCombineNoResult(_ target: API) -> AnyPublisher<Int, Error> {
        Future { promise in
            self.provider.request(target) { response in
                switch response {
                case .success(let value):
                    // 바디 decode 없이 HTTP 상태 코드만 반환
                    promise(.success(value.statusCode))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
}
