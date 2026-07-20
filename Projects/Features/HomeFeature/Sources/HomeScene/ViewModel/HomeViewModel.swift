import Combine

import Core
import Domain

public final class HomeViewModel {

    // MARK: - Navigation Callbacks (set by Coordinator)

    public var onDrugIdentifyTapped: (() -> Void)?
    public var onTreatmentTimerTapped: (() -> Void)?

    // MARK: - Input / Output

    public struct Input {
        public let viewDidLoad: AnyPublisher<Void, Never>
        public let viewWillAppear: AnyPublisher<Void, Never>
        public let drugIdentifyTapped: AnyPublisher<Void, Never>
        public let treatmentTimerTapped: AnyPublisher<Void, Never>

        public init(
            viewDidLoad: AnyPublisher<Void, Never>,
            viewWillAppear: AnyPublisher<Void, Never>,
            drugIdentifyTapped: AnyPublisher<Void, Never>,
            treatmentTimerTapped: AnyPublisher<Void, Never>
        ) {
            self.viewDidLoad = viewDidLoad
            self.viewWillAppear = viewWillAppear
            self.drugIdentifyTapped = drugIdentifyTapped
            self.treatmentTimerTapped = treatmentTimerTapped
        }
    }

    public struct Output {
        public let isLoading: AnyPublisher<Bool, Never>
        public let error: AnyPublisher<String, Never>
        /// 알약 식별 카드에 표시할 남은 횟수. nil이면 아직 모르는 상태라 표시하지 않는다.
        public let usage: AnyPublisher<PillUsageModel?, Never>
        /// 한도 소진 상태에서 카드를 탭했을 때 — 안내 팝업을 띄운다.
        public let limitExceeded: AnyPublisher<PillUsageModel?, Never>
    }

    private var cancelBag = Set<AnyCancellable>()

    @Injected private var pillUseCase: PillUseCase

    public init() {}

    public func transform(input: Input) -> Output {
        let isLoading = PassthroughSubject<Bool, Never>()
        let error = PassthroughSubject<String, Never>()
        let limitExceeded = PassthroughSubject<PillUsageModel?, Never>()

        // 식별을 마치고 홈으로 돌아왔을 때도 갱신되도록 willAppear마다 조회한다.
        // 조회 전용이라 카운트는 늘지 않는다 (NM-331).
        input.viewWillAppear
            .sink { [weak self] in self?.pillUseCase.fetchPillUsage() }
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

        return Output(
            isLoading: isLoading.eraseToAnyPublisher(),
            error: error.eraseToAnyPublisher(),
            usage: pillUseCase.pillUsage.eraseToAnyPublisher(),
            limitExceeded: limitExceeded.eraseToAnyPublisher()
        )
    }
}
