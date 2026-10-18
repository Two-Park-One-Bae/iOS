import Combine

import Core
import Domain

public final class HomeViewModel {

    // MARK: - Navigation Callbacks (set by Coordinator)

    public var onDrugIdentifyTapped: (() -> Void)?
    public var onTreatmentTimerTapped: (() -> Void)?
    /// 최근 식별 칩 → 그 기록의 상세 (NM-552)
    public var onRecentHistoryTapped: ((PillHistorySummaryModel) -> Void)?

    // MARK: - Input / Output

    public struct Input {
        public let viewDidLoad: AnyPublisher<Void, Never>
        public let viewWillAppear: AnyPublisher<Void, Never>
        public let drugIdentifyTapped: AnyPublisher<Void, Never>
        public let treatmentTimerTapped: AnyPublisher<Void, Never>
        public let recentHistoryTapped: AnyPublisher<Void, Never>

        public init(
            viewDidLoad: AnyPublisher<Void, Never>,
            viewWillAppear: AnyPublisher<Void, Never>,
            drugIdentifyTapped: AnyPublisher<Void, Never>,
            treatmentTimerTapped: AnyPublisher<Void, Never>,
            recentHistoryTapped: AnyPublisher<Void, Never> = Empty().eraseToAnyPublisher()
        ) {
            self.viewDidLoad = viewDidLoad
            self.viewWillAppear = viewWillAppear
            self.drugIdentifyTapped = drugIdentifyTapped
            self.treatmentTimerTapped = treatmentTimerTapped
            self.recentHistoryTapped = recentHistoryTapped
        }
    }

    public struct Output {
        public let isLoading: AnyPublisher<Bool, Never>
        public let error: AnyPublisher<String, Never>
        /// 알약 식별 카드에 표시할 남은 횟수. nil이면 아직 모르는 상태라 표시하지 않는다.
        public let usage: AnyPublisher<PillUsageModel?, Never>
        /// 한도 소진 상태에서 카드를 탭했을 때 — 안내 팝업을 띄운다.
        public let limitExceeded: AnyPublisher<PillUsageModel?, Never>
        /// 활성(진행 중, running) 타이머 개수. 칩에 "활성 타이머 N"으로 표시한다.
        public let activeTimerCount: AnyPublisher<Int, Never>
        /// 가장 최근 식별 기록 — 최근 식별 칩. 기록이 없거나 불러오지 못했으면 nil(칩을 숨긴다)
        public let latestHistory: AnyPublisher<PillHistorySummaryModel?, Never>
    }

    private var cancelBag = Set<AnyCancellable>()

    @Injected private var pillUseCase: PillUseCase
    @Injected private var timerUseCase: TimerUseCase
    @Injected private var historyUseCase: PillHistoryUseCase

    private let latestHistory = CurrentValueSubject<PillHistorySummaryModel?, Never>(nil)
    private var historyRequest: AnyCancellable?

    public init() {}

    public func transform(input: Input) -> Output {
        let isLoading = PassthroughSubject<Bool, Never>()
        let error = PassthroughSubject<String, Never>()
        let limitExceeded = PassthroughSubject<PillUsageModel?, Never>()

        // 식별을 마치고 홈으로 돌아왔을 때도 갱신되도록 willAppear마다 조회한다.
        // 조회 전용이라 카운트는 늘지 않는다 (NM-331).
        input.viewWillAppear
            .sink { [weak self] in
                self?.pillUseCase.fetchPillUsage()
                // 위젯·라이브액티비티 등 다른 프로세스에서 시작된 타이머까지 반영되도록 재동기화.
                self?.timerUseCase.reload()
                // 식별을 저장하거나 기록을 지우고 돌아왔을 때 맞는 칩을 보이도록 보일 때마다 다시 받는다.
                self?.fetchLatestHistory()
            }
            .store(in: &cancelBag)

        input.recentHistoryTapped
            .sink { [weak self] in
                guard let self, let summary = self.latestHistory.value else { return }
                self.onRecentHistoryTapped?(summary)
            }
            .store(in: &cancelBag)

        input.drugIdentifyTapped
            .sink { [weak self] in
                guard let self else { return }

                // 게이트: 남은 횟수가 0일 때만 막는다.
                // 값을 모르면(조회 실패·서버 미적용) 통과시킨다 — 최종 판정은 서버 429다.
                if let usage = self.pillUseCase.pillUsage.value, usage.isExhausted {
                    limitExceeded.send(usage)
                    return
                }

                self.onDrugIdentifyTapped?()
            }
            .store(in: &cancelBag)

        input.treatmentTimerTapped
            .sink { [weak self] in self?.onTreatmentTimerTapped?() }
            .store(in: &cancelBag)

        // 진행 중(running)인 타이머만 센다 — 일시정지·울림 제외.
        let activeTimerCount = timerUseCase.timers
            .map { $0.filter { $0.state == .running }.count }
            .removeDuplicates()
            .eraseToAnyPublisher()

        return Output(
            isLoading: isLoading.eraseToAnyPublisher(),
            error: error.eraseToAnyPublisher(),
            usage: pillUseCase.pillUsage.eraseToAnyPublisher(),
            limitExceeded: limitExceeded.eraseToAnyPublisher(),
            activeTimerCount: activeTimerCount,
            latestHistory: latestHistory.removeDuplicates().eraseToAnyPublisher()
        )
    }

    /// 실패하면 칩을 숨긴다 — 홈에 다시 돌아오면 다시 받는다.
    private func fetchLatestHistory() {
        historyRequest = historyUseCase.fetchLatestHistory()
            .replaceError(with: nil)
            .sink { [weak self] summary in self?.latestHistory.send(summary) }
    }
}
