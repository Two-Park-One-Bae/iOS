//
//  PillHistoryRepositoryInterface.swift
//  Domain
//

import Combine

public protocol PillHistoryRepositoryProtocol {
    // 식별 기록 요약 목록, 최신순 (NM-552). cursor가 nil이면 처음부터.
    func fetchHistories(limit: Int, cursor: String?) -> AnyPublisher<PillHistoryPageModel, Error>
    // 기록 한 건. 없으면 PillHistoryNotFoundError
    func fetchHistory(historyId: String) -> AnyPublisher<PillHistoryModel, Error>
    // 확정한 품목 저장 — 같은 historyId 면 통째로 바뀐다. 400이면 PillHistoryRejectedError
    func saveHistory(historyId: String, pillCodes: [String]) -> AnyPublisher<Void, Error>
    // 삭제 — 이미 없어도 성공
    func deleteHistory(historyId: String) -> AnyPublisher<Void, Error>
}
