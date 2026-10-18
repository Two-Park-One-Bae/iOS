//
//  PillHistoryUseCase.swift
//  Domain
//

import Combine

/// 식별 기록 (NM-552). 화면마다 부르는 시점이 달라(홈은 보일 때마다 1건, 알약 탭은 이어서 받기)
/// 공유 채널이 아니라 publisher 로 돌려준다.
public protocol PillHistoryUseCase {
    // 식별 기록 요약 목록, 최신순. limit 1~50 (서버 기본 20)
    func fetchHistories(limit: Int, cursor: String?) -> AnyPublisher<PillHistoryPageModel, Error>
    // 가장 최근 기록 한 건 — 홈 최근 식별 칩. 기록이 없으면 nil
    func fetchLatestHistory() -> AnyPublisher<PillHistorySummaryModel?, Error>
    // 기록 한 건 — 기록 상세. 없으면 PillHistoryNotFoundError
    func fetchHistory(historyId: String) -> AnyPublisher<PillHistoryModel, Error>
    // 식별 결과 `완료` 때 확정한 품목 저장. 400이면 PillHistoryRejectedError
    func saveHistory(historyId: String, pillCodes: [String]) -> AnyPublisher<Void, Error>
    func deleteHistory(historyId: String) -> AnyPublisher<Void, Error>
}

public final class DefaultPillHistoryUseCase: PillHistoryUseCase {
    private let repository: PillHistoryRepositoryProtocol

    public init(repository: PillHistoryRepositoryProtocol) {
        self.repository = repository
    }

    public func fetchHistories(limit: Int, cursor: String?) -> AnyPublisher<PillHistoryPageModel, Error> {
        repository.fetchHistories(limit: limit, cursor: cursor)
    }

    public func fetchLatestHistory() -> AnyPublisher<PillHistorySummaryModel?, Error> {
        repository.fetchHistories(limit: 1, cursor: nil)
            .map(\.items.first)
            .eraseToAnyPublisher()
    }

    public func fetchHistory(historyId: String) -> AnyPublisher<PillHistoryModel, Error> {
        repository.fetchHistory(historyId: historyId)
    }

    public func saveHistory(historyId: String, pillCodes: [String]) -> AnyPublisher<Void, Error> {
        repository.saveHistory(historyId: historyId, pillCodes: pillCodes)
    }

    public func deleteHistory(historyId: String) -> AnyPublisher<Void, Error> {
        repository.deleteHistory(historyId: historyId)
    }
}
