import UIKit
import Combine
import SnapKit
import Then
import DSKit
import Domain

// C1 타이머 리스트 — 헤더(제목+상태 카운트), 만료 카드 맨 위, 진행 카드들, 빈 상태, FAB
public final class TimerListVC: UIViewController {

    // MARK: - Callbacks

    var onAddTapped: (() -> Void)?

    // MARK: - Properties

    private let viewModel: TimerListViewModel
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private var cancelBag = Set<AnyCancellable>()

    private var runningCards: [UUID: TimerCardView] = [:]
    private var renderedIDs: [UUID] = []
    private var renderedStates: [UUID: TreatmentTimerState] = [:]

    // MARK: - UI

    private let titleLabel = UILabel().then {
        $0.text = "타이머"
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 24)
        $0.textColor = DSColor.textPrimary
    }
    private let countLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
        $0.textColor = DSColor.textSecondary
    }

    private let scrollView = UIScrollView().then {
        $0.showsVerticalScrollIndicator = false
        $0.alwaysBounceVertical = true
    }
    private let cardsStack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 12
        $0.isLayoutMarginsRelativeArrangement = true
        $0.layoutMargins = UIEdgeInsets(top: 12, left: 20, bottom: 96, right: 20)
    }

    private let emptyView = TimerEmptyView().then { $0.isHidden = true }

    private let fab = UIButton(type: .system).then {
        $0.backgroundColor = DSColor.Primary._500
        $0.layer.cornerRadius = 28
        $0.setImage(
            UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)),
            for: .normal
        )
        $0.tintColor = DSColor.Neutral._0
        $0.layer.shadowColor = DSColor.Primary._600.cgColor
        $0.layer.shadowOpacity = 0.4
        $0.layer.shadowOffset = CGSize(width: 0, height: 4)
        $0.layer.shadowRadius = 16
    }

    // MARK: - Init

    init(viewModel: TimerListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        setUI()
        setLayout()
        bind()
        viewDidLoadSubject.send(())
    }

    // MARK: - Setup

    private func setUI() {
        view.backgroundColor = DSColor.bgApp
        fab.addAction(UIAction { [weak self] _ in self?.onAddTapped?() }, for: .touchUpInside)
        emptyView.onStart = { [weak self] in self?.onAddTapped?() }
    }

    private func setLayout() {
        let header = UIStackView(arrangedSubviews: [titleLabel, countLabel]).then {
            $0.axis = .vertical
            $0.spacing = 4
            $0.alignment = .leading
        }
        view.addSubview(header)
        header.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            $0.leading.trailing.equalToSuperview().inset(20)
        }

        view.addSubview(scrollView)
        scrollView.addSubview(cardsStack)
        scrollView.snp.makeConstraints {
            $0.top.equalTo(header.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        cardsStack.snp.makeConstraints {
            $0.edges.equalTo(scrollView.contentLayoutGuide)
            $0.width.equalTo(scrollView.frameLayoutGuide)
        }

        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.center.equalTo(scrollView)
            $0.leading.trailing.equalToSuperview().inset(20)
        }

        view.addSubview(fab)
        fab.snp.makeConstraints {
            $0.width.height.equalTo(56)
            $0.trailing.equalToSuperview().inset(20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(16)
        }
    }

    // MARK: - Bind

    private func bind() {
        let output = viewModel.transform(
            input: TimerListViewModel.Input(viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher())
        )

        output.timers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timers in self?.render(timers) }
            .store(in: &cancelBag)

        output.tick
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.tick() }
            .store(in: &cancelBag)
    }

    // MARK: - Render

    // 구조 변화(추가/삭제/상태 전이) 시 전체 재구성, 매초는 tick()으로 링만 갱신
    private func render(_ timers: [TreatmentTimerModel]) {
        let sorted = sortedForDisplay(timers)
        let structureChanged = sorted.map(\.id) != renderedIDs
            || sorted.contains { renderedStates[$0.id] != $0.state }

        updateCountLabel(timers)
        emptyView.isHidden = !timers.isEmpty
        fab.isHidden = false

        guard structureChanged else {
            for timer in sorted where timer.state != .ringing {
                runningCards[timer.id]?.render(timer)
            }
            return
        }

        renderedIDs = sorted.map(\.id)
        renderedStates = Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0.state) })
        cardsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        runningCards.removeAll()

        for timer in sorted {
            if timer.state == .ringing {
                let card = RingingTimerCardView(timer: timer)
                card.onComplete = { [weak self] in self?.viewModel.remove(id: timer.id) }
                cardsStack.addArrangedSubview(card)
            } else {
                let card = TimerCardView(timerID: timer.id)
                card.onPauseOrResume = { [weak self] in
                    guard let current = self?.viewModel.currentTimers.first(where: { $0.id == timer.id }) else { return }
                    self?.viewModel.pauseOrResume(current)
                }
                card.onExtend = { [weak self] in self?.viewModel.extendOneMinute(id: timer.id) }
                card.onStop = { [weak self] in self?.viewModel.remove(id: timer.id) }
                card.onMemoSave = { [weak self] memo in self?.viewModel.updateMemo(id: timer.id, memo: memo) }
                card.render(timer)
                runningCards[timer.id] = card
                cardsStack.addArrangedSubview(card)
            }
        }
    }

    private func tick() {
        render(viewModel.currentTimers)
    }

    // 만료(RINGING) 카드가 맨 위 (spec)
    private func sortedForDisplay(_ timers: [TreatmentTimerModel]) -> [TreatmentTimerModel] {
        let ringing = timers.filter { $0.state == .ringing }
        let others = timers.filter { $0.state != .ringing }
        return ringing + others
    }

    private func updateCountLabel(_ timers: [TreatmentTimerModel]) {
        let running = timers.filter { $0.state == .running }.count
        let paused = timers.filter { $0.state == .paused }.count
        let ringing = timers.filter { $0.state == .ringing }.count
        var parts: [String] = []
        if running > 0 { parts.append("진행 중 \(running)") }
        if paused > 0 { parts.append("일시정지 \(paused)") }
        if ringing > 0 { parts.append("종료 \(ringing)") }
        countLabel.text = parts.joined(separator: " · ")
        countLabel.isHidden = parts.isEmpty
    }
}
