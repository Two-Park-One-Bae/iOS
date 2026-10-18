import Combine
import Foundation
import Core
import Domain

// 알약 탭 — 식별 기록 목록 (NM-552). 최신순으로 20건씩 이어서 받고, 날짜별로 묶는다.
final class PillHistoryListViewModel {

    // MARK: - State

    struct Section: Equatable {
        let title: String
        let items: [PillHistorySummaryModel]
    }

    /// 목록 끝 한 줄.
    enum Footer: Equatable {
        case none
        case loadingMore
        /// 이어서 받기 실패 — 이미 보이는 기록은 두고 끝에 `다시 시도`
        case loadMoreFailed
        /// 끝까지 받았다. 보관 상한(100건)에 닿았으면 안내 문구를 둔다
        case end(reachedCap: Bool)
    }

    enum State: Equatable {
        case loading
        case empty
        case failed
        case loaded(sections: [Section], footer: Footer)
    }

    // MARK: - Input / Output

    struct Input {
        /// 화면이 보일 때마다 — 식별을 저장하거나 기록을 지우고 돌아오면 맞는 목록을 보이기 위해 처음부터 다시 받는다
        let viewWillAppear: AnyPublisher<Void, Never>
        let retry: AnyPublisher<Void, Never>
        /// 목록 끝 근처까지 스크롤 · 이어서 받기 `다시 시도`
        let loadMore: AnyPublisher<Void, Never>
    }

    struct Output {
        let state: AnyPublisher<State, Never>
        /// 오늘 남은 횟수 — 홈 카드와 같은 값. nil이면 아직 모른다
        let usage: AnyPublisher<PillUsageModel?, Never>
    }

    // MARK: - Dependencies

    @Injected private var historyUseCase: PillHistoryUseCase
    @Injected private var pillUseCase: PillUseCase

    private static let pageSize = 20
    /// 서버 보관 상한 (spec: domains/history.md)
    private static let storageCap = 100

    private var cancelBag = Set<AnyCancellable>()
    private var requestBag = Set<AnyCancellable>()
    private let stateSubject = CurrentValueSubject<State, Never>(.loading)

    private var items: [PillHistorySummaryModel] = []
    private var nextCursor: String?
    private var isLoadingMore = false

    // MARK: - Transform

    func transform(input: Input) -> Output {
        Publishers.Merge(input.viewWillAppear, input.retry)
            .sink { [weak self] in self?.loadFirstPage() }
            .store(in: &cancelBag)

        input.loadMore
            .sink { [weak self] in self?.loadNextPage() }
            .store(in: &cancelBag)

        return Output(
            state: stateSubject.removeDuplicates().eraseToAnyPublisher(),
            usage: pillUseCase.pillUsage.eraseToAnyPublisher()
        )
    }

    // MARK: - Pipeline

    private func loadFirstPage() {
        requestBag.removeAll()
        isLoadingMore = false
        // 이미 보이는 목록이 있으면 그대로 두고 응답이 오면 바꾼다 — 돌아올 때마다 깜빡이지 않게.
        if items.isEmpty { stateSubject.send(.loading) }
        pillUseCase.fetchPillUsage()

        historyUseCase.fetchHistories(limit: Self.pageSize, cursor: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard case .failure = completion, let self else { return }
                self.items = []
                self.nextCursor = nil
                self.stateSubject.send(.failed)
            } receiveValue: { [weak self] page in
                guard let self else { return }
                self.items = page.items
                self.nextCursor = page.nextCursor
                self.publish(footerOverride: nil)
            }
            .store(in: &requestBag)
    }

    private func loadNextPage() {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        publish(footerOverride: .loadingMore)

        historyUseCase.fetchHistories(limit: Self.pageSize, cursor: cursor)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard case .failure = completion, let self else { return }
                self.isLoadingMore = false
                // 자동으로 다시 시도하지 않는다 — 끝에 `다시 시도`를 둔다.
                self.publish(footerOverride: .loadMoreFailed)
            } receiveValue: { [weak self] page in
                guard let self else { return }
                self.isLoadingMore = false
                self.items += page.items
                self.nextCursor = page.nextCursor
                self.publish(footerOverride: nil)
            }
            .store(in: &requestBag)
    }

    private func publish(footerOverride: Footer?) {
        guard !items.isEmpty else {
            stateSubject.send(.empty)
            return
        }
        let footer = footerOverride
            ?? (nextCursor == nil ? .end(reachedCap: items.count >= Self.storageCap) : .none)
        stateSubject.send(.loaded(sections: Self.group(items), footer: footer))
    }

    /// 날짜(기기 시간대)별로 묶는다. 서버가 최신순으로 주므로 순서는 그대로다.
    private static func group(_ items: [PillHistorySummaryModel]) -> [Section] {
        var sections: [Section] = []
        for item in items {
            let title = item.identifiedAt.map { PillHistoryDateText.sectionTitle($0) } ?? "날짜 미상"
            if let last = sections.last, last.title == title {
                sections[sections.count - 1] = Section(title: title, items: last.items + [item])
            } else {
                sections.append(Section(title: title, items: [item]))
            }
        }
        return sections
    }
}
