import Combine
import Foundation

import Core
import Domain

// 홈 (V2.1.0 — NM-585 · NM-609). spec: feature/home/README.md
public final class HomeViewModel {

    // MARK: - Navigation Callbacks (set by Coordinator)

    /// `사진 찍기` → 곧장 촬영
    public var onCaptureTapped: (() -> Void)?
    /// `알약 식별` 카드의 나머지 → 알약 탭
    public var onPillTabTapped: (() -> Void)?
    /// `새 타이머` → 타이머 탭 + 프리셋 시트
    public var onNewTimerTapped: (() -> Void)?
    /// `처치 타이머` 카드의 나머지 · 진행 중인 타이머 카드 → 타이머 탭
    public var onTimerTabTapped: (() -> Void)?
    /// 최근 식별 카드 → 그 기록의 상세 (NM-552)
    public var onRecentHistoryTapped: ((PillHistorySummaryModel) -> Void)?

    // MARK: - State

    /// 진행 중인 타이머 카드 — 최대 3줄, 4개 이상이면 `전체 보기`
    public struct TimerList: Equatable {
        public let rows: [TreatmentTimerModel]
        public let totalCount: Int

        public var showsAll: Bool { totalCount > rows.count }
    }

    public enum RecentHistory: Equatable {
        case loading
        case item(PillHistorySummaryModel)
        case empty
        case failed
    }

    // MARK: - Input / Output

    public struct Input {
        public let viewWillAppear: AnyPublisher<Void, Never>
        public let captureTapped: AnyPublisher<Void, Never>
        public let pillCardTapped: AnyPublisher<Void, Never>
        public let newTimerTapped: AnyPublisher<Void, Never>
        public let timerCardTapped: AnyPublisher<Void, Never>
        public let recentHistoryTapped: AnyPublisher<Void, Never>

        public init(
            viewWillAppear: AnyPublisher<Void, Never>,
            captureTapped: AnyPublisher<Void, Never> = Empty().eraseToAnyPublisher(),
            pillCardTapped: AnyPublisher<Void, Never> = Empty().eraseToAnyPublisher(),
            newTimerTapped: AnyPublisher<Void, Never> = Empty().eraseToAnyPublisher(),
            timerCardTapped: AnyPublisher<Void, Never> = Empty().eraseToAnyPublisher(),
            recentHistoryTapped: AnyPublisher<Void, Never> = Empty().eraseToAnyPublisher()
        ) {
            self.viewWillAppear = viewWillAppear
            self.captureTapped = captureTapped
            self.pillCardTapped = pillCardTapped
            self.newTimerTapped = newTimerTapped
            self.timerCardTapped = timerCardTapped
            self.recentHistoryTapped = recentHistoryTapped
        }
    }

    public struct Output {
        /// 알약 식별 카드의 남은 횟수. nil이면 모르는 상태(`–`, `사진 찍기`는 활성)
        public let usage: AnyPublisher<PillUsageModel?, Never>
        /// 처치 타이머 카드의 개수 — 진행 중 · 일시정지 · 만료를 모두 센다
        public let timerCount: AnyPublisher<Int, Never>
        public let timerList: AnyPublisher<TimerList, Never>
        public let recentHistory: AnyPublisher<RecentHistory, Never>
    }

    private var cancelBag = Set<AnyCancellable>()

    @Injected private var pillUseCase: PillUseCase
    @Injected private var timerUseCase: TimerUseCase
    @Injected private var historyUseCase: PillHistoryUseCase

    private let recentHistory = CurrentValueSubject<RecentHistory, Never>(.loading)
    private var historyRequest: AnyCancellable?

    private static let maxTimerRows = 3

    public init() {}

    public func transform(input: Input) -> Output {
        // 식별을 마치고 돌아왔을 때도 갱신되도록 willAppear마다 조회한다.
        // 잔여 조회는 조회 전용이라 카운트가 늘지 않는다 (NM-331).
        input.viewWillAppear
            .sink { [weak self] in
                self?.pillUseCase.fetchPillUsage()
                // 위젯·라이브액티비티 등 다른 프로세스에서 시작된 타이머까지 반영되도록 재동기화.
                self?.timerUseCase.reload()
                // 식별을 저장하거나 기록을 지우고 돌아왔을 때 맞는 값을 보이도록 보일 때마다 다시 받는다.
                self?.fetchLatestHistory()
            }
            .store(in: &cancelBag)

        input.captureTapped
            .sink { [weak self] in
                guard let self else { return }
                // 0회면 버튼이 비활성이다 — 팝업 없이 막는다(카드가 이유와 초기화 시각을 보여 준다).
                // 값을 모르면 통과한다 — 막을지는 서버가 판정한다(429).
                if let usage = self.pillUseCase.pillUsage.value, usage.isExhausted { return }
                self.onCaptureTapped?()
            }
            .store(in: &cancelBag)

        input.pillCardTapped
            .sink { [weak self] in self?.onPillTabTapped?() }
            .store(in: &cancelBag)

        input.newTimerTapped
            .sink { [weak self] in self?.onNewTimerTapped?() }
            .store(in: &cancelBag)

        input.timerCardTapped
            .sink { [weak self] in self?.onTimerTabTapped?() }
            .store(in: &cancelBag)

        input.recentHistoryTapped
            .sink { [weak self] in
                guard let self, case .item(let summary) = self.recentHistory.value else { return }
                self.onRecentHistoryTapped?(summary)
            }
            .store(in: &cancelBag)

        let timers = timerUseCase.timers.share()

        return Output(
            usage: pillUseCase.pillUsage.eraseToAnyPublisher(),
            timerCount: timers.map(\.count).removeDuplicates().eraseToAnyPublisher(),
            timerList: timers
                .map { Self.makeTimerList($0) }
                .removeDuplicates()
                .eraseToAnyPublisher(),
            recentHistory: recentHistory.removeDuplicates().eraseToAnyPublisher()
        )
    }

    /// 순서: 만료 → 진행 중(남은 시간이 짧은 순) → 일시정지. 3줄까지만.
    static func makeTimerList(_ timers: [TreatmentTimerModel], now: Date = Date()) -> TimerList {
        func rank(_ timer: TreatmentTimerModel) -> Int {
            switch timer.state {
            case .ringing: return 0
            case .running: return 1
            case .paused:  return 2
            }
        }
        let sorted = timers.sorted {
            let (a, b) = (rank($0), rank($1))
            if a != b { return a < b }
            return $0.remainingSeconds(at: now) < $1.remainingSeconds(at: now)
        }
        return TimerList(rows: Array(sorted.prefix(maxTimerRows)), totalCount: timers.count)
    }

    /// 이미 보이는 값이 있으면 그대로 두고 응답이 오면 바꾼다 — 돌아올 때마다 깜빡이지 않게.
    private func fetchLatestHistory() {
        historyRequest = historyUseCase.fetchLatestHistory()
            .map { summary -> RecentHistory in summary.map { .item($0) } ?? .empty }
            .catch { _ in Just(.failed) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.recentHistory.send(state) }
    }
}
