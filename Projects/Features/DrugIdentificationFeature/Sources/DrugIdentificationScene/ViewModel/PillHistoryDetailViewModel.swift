import Combine
import Foundation
import Core
import Domain

// 기록 상세 (NM-552). 목록 · 홈 칩은 요약만 받으므로 알약 목록은 열 때 한 건을 조회한다.
final class PillHistoryDetailViewModel {

    // MARK: - State

    enum State {
        /// 요약으로 받은 알약 수만큼 자리 표시 행을 둔다
        case loading(placeholderCount: Int)
        case loaded(PillHistoryModel)
        case failed
        /// 다른 기기에서 지웠거나 100건 상한으로 지워진 기록 — 들어온 화면으로 돌아간다
        case notFound
    }

    // MARK: - Input / Output

    struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
        let retry: AnyPublisher<Void, Never>
        /// 삭제 확인 모달의 `삭제`
        let delete: AnyPublisher<Void, Never>
    }

    struct Output {
        let state: AnyPublisher<State, Never>
        /// 머리의 식별 시각 — 요약으로 받은 값이라 조회 중 · 실패에도 바로 보인다
        let identifiedAtText: String?
        let deleted: AnyPublisher<Void, Never>
        let deleteFailed: AnyPublisher<Void, Never>
    }

    // MARK: - Dependencies

    @Injected private var historyUseCase: PillHistoryUseCase

    private let historyId: String
    private let identifiedAt: Date?
    private let pillCount: Int
    private var cancelBag = Set<AnyCancellable>()
    private var requestBag = Set<AnyCancellable>()
    private let stateSubject: CurrentValueSubject<State, Never>
    private let deletedSubject = PassthroughSubject<Void, Never>()
    private let deleteFailedSubject = PassthroughSubject<Void, Never>()

    // MARK: - Init

    init(summary: PillHistorySummaryModel) {
        self.historyId = summary.historyId
        self.identifiedAt = summary.identifiedAt
        self.pillCount = summary.pillCount
        self.stateSubject = CurrentValueSubject(.loading(placeholderCount: summary.pillCount))
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        Publishers.Merge(input.viewDidLoad, input.retry)
            .sink { [weak self] in self?.load() }
            .store(in: &cancelBag)

        input.delete
            .sink { [weak self] in self?.delete() }
            .store(in: &cancelBag)

        return Output(
            state: stateSubject.eraseToAnyPublisher(),
            identifiedAtText: identifiedAt.map { PillHistoryDateText.detail($0) },
            deleted: deletedSubject.eraseToAnyPublisher(),
            deleteFailed: deleteFailedSubject.eraseToAnyPublisher()
        )
    }

    // MARK: - Pipeline

    private func load() {
        requestBag.removeAll()
        stateSubject.send(.loading(placeholderCount: pillCount))
        historyUseCase.fetchHistory(historyId: historyId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard case .failure(let error) = completion else { return }
                self?.stateSubject.send(error is PillHistoryNotFoundError ? .notFound : .failed)
            } receiveValue: { [weak self] history in
                self?.stateSubject.send(.loaded(history))
            }
            .store(in: &requestBag)
    }

    private func delete() {
        historyUseCase.deleteHistory(historyId: historyId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard case .failure = completion else { return }
                self?.deleteFailedSubject.send(())
            } receiveValue: { [weak self] in
                self?.deletedSubject.send(())
            }
            .store(in: &cancelBag)
    }
}
