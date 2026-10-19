//
//  PillHistoryRepository.swift
//  Data
//

import Combine
import Foundation

import Domain
import Networks

public final class PillHistoryRepository: PillHistoryRepositoryProtocol {
    private let service: PillService

    public init(service: PillService) {
        self.service = service
    }

    public func fetchHistories(limit: Int, cursor: String?) -> AnyPublisher<PillHistoryPageModel, Error> {
        service.fetchPillHistories(limit: limit, cursor: cursor)
            .map { $0.toDomain() }
            .eraseToAnyPublisher()
    }

    public func fetchHistory(historyId: String) -> AnyPublisher<PillHistoryModel, Error> {
        service.fetchPillHistory(historyId: historyId)
            .map { $0.toDomain() }
            .mapError { Self.mapStatus($0, 404, to: PillHistoryNotFoundError()) }
            .eraseToAnyPublisher()
    }

    public func saveHistory(historyId: String, pillCodes: [String]) -> AnyPublisher<Void, Error> {
        service.savePillHistory(historyId: historyId, pillCodes: pillCodes)
            .mapError { Self.mapStatus($0, 400, to: PillHistoryRejectedError()) }
            .eraseToAnyPublisher()
    }

    public func deleteHistory(historyId: String) -> AnyPublisher<Void, Error> {
        service.deletePillHistory(historyId: historyId)
    }

    /// 화면이 분기해야 하는 상태코드 하나만 도메인 에러로 올린다. 나머지는 그대로 통과.
    private static func mapStatus(_ error: Error, _ statusCode: Int, to mapped: Error) -> Error {
        guard case APIError.network(let code, _) = error, code == statusCode else { return error }
        return mapped
    }
}
