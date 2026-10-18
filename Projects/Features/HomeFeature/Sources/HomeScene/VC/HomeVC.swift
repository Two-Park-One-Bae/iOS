import UIKit
import Combine
import SnapKit
import Then
import DSKit
import Domain

public final class HomeVC: UIViewController {

    // MARK: - Properties

    private let viewModel: HomeViewModel
    private var cancelBag = Set<AnyCancellable>()

    private let viewWillAppearSubject = PassthroughSubject<Void, Never>()
    private let drugIdentifySubject = PassthroughSubject<Void, Never>()
    private let treatmentTimerSubject = PassthroughSubject<Void, Never>()
    private let recentHistorySubject = PassthroughSubject<Void, Never>()

    // MARK: - UI

    private let scrollView = UIScrollView().then {
        $0.showsVerticalScrollIndicator = false
    }

    private let contentStack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 20
    }

    private let greetingLabel = UILabel().then {
        $0.text = "안녕하세요,"
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 28)
        $0.textColor = DSColor.textSecondary
    }

    private let roleLabel = UILabel().then {
        $0.text = "간호사님"
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 28)
        $0.textColor = DSColor.textPrimary
    }

    private let dateLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
        $0.textColor = DSColor.textTertiary
        $0.text = HomeVC.todayText()
    }

    private lazy var greetingStack = UIStackView(arrangedSubviews: [greetingLabel, roleLabel, dateLabel]).then {
        $0.axis = .vertical
        $0.spacing = 2
        $0.setCustomSpacing(8, after: roleLabel)
    }

    // MARK: - Init

    public init(viewModel: HomeViewModel) {
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
        buildContent()
        bind()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 식별을 마치고 돌아왔을 때 남은 횟수를 갱신한다.
        viewWillAppearSubject.send()
    }

    // MARK: - Setup

    private func setUI() {
        view.backgroundColor = DSColor.bgApp
    }

    private func setLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        scrollView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        contentStack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20))
            $0.width.equalToSuperview().offset(-40)
        }
    }

    // MARK: - Content

    private func buildContent() {
        contentStack.addArrangedSubview(greetingStack)
        contentStack.addArrangedSubview(makeChipsRow())
        contentStack.addArrangedSubview(makeCardsSection())
    }

    // 오늘 날짜 — "M월 d일 EEEE"(예: 7월 23일 수요일).
    private static func todayText() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: Date())
    }

    // 활성 타이머 수를 갱신해야 해서 프로퍼티로 유지한다.
    private let timerChip = DSChip(text: "활성 타이머 0", icon: .timer, style: .secondary)

    // 최근 식별 칩 — 가장 최근 기록 한 건. 기록이 없거나 불러오지 못했으면 숨긴다 (NM-552, 디자인 `CwGWk`).
    private let recentChip = RecentHistoryChip().then { $0.isHidden = true }

    private func makeChipsRow() -> UIView {
        let spacer = UIView()
        // 품목명이 길면 최근 식별 칩이 줄어든다 — 타이머 칩은 그대로 둔다.
        timerChip.setContentCompressionResistancePriority(.required, for: .horizontal)
        recentChip.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        recentChip.addAction(UIAction { [weak self] _ in self?.recentHistorySubject.send() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [timerChip, recentChip, spacer]).then {
            $0.axis = .horizontal
            $0.spacing = 8
        }
        return stack
    }

    // 남은 횟수를 갱신해야 해서 프로퍼티로 유지한다.
    private let drugCard = DSListRow(
        icon: .pill,
        title: "알약 식별",
        subtitle: "환자 지참약을 한 번에 식별하고 정보를 확인하세요."
    )

    private func makeCardsSection() -> UIView {
        drugCard.setIconBackground(DSColor.Primary._50)
        drugCard.setIconTint(DSColor.Primary._500)
        drugCard.onTap { [weak self] in self?.drugIdentifySubject.send() }

        let timerCard = DSListRow(
            icon: .timer,
            title: "처치 타이머",
            subtitle: "투약 및 처치 시간을 체계적으로 관리하세요."
        )
        timerCard.setIconBackground(DSColor.Secondary._50)
        timerCard.setIconTint(DSColor.Secondary._500)
        timerCard.onTap { [weak self] in self?.treatmentTimerSubject.send() }

        let stack = UIStackView(arrangedSubviews: [drugCard, timerCard]).then {
            $0.axis = .vertical
            $0.spacing = 12
        }
        return stack
    }

    // MARK: - Bind

    private func bind() {
        let input = HomeViewModel.Input(
            viewDidLoad: Just(()).eraseToAnyPublisher(),
            viewWillAppear: viewWillAppearSubject.eraseToAnyPublisher(),
            drugIdentifyTapped: drugIdentifySubject.eraseToAnyPublisher(),
            treatmentTimerTapped: treatmentTimerSubject.eraseToAnyPublisher(),
            recentHistoryTapped: recentHistorySubject.eraseToAnyPublisher()
        )
        let output = viewModel.transform(input: input)

        // 남은 횟수 — 0회일 때만 경고색, 그 외엔 기본색. 값을 모르면 표시하지 않는다.
        output.usage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] usage in
                guard let usage else {
                    self?.drugCard.setCaption(nil)
                    return
                }
                self?.drugCard.setCaption(
                    usage.remainingText,
                    color: usage.isExhausted ? DSColor.Error._600 : DSColor.Primary._600
                )
            }
            .store(in: &cancelBag)

        output.limitExceeded
            .receive(on: DispatchQueue.main)
            .sink { usage in
                // 식별 플로우의 한도 팝업과 같은 표현을 쓴다 — dim이 탭바까지 덮는다(디자인 기준).
                DSAlertCardView.presentOverWindow(
                    title: PillLimitAlertText.title,
                    message: PillLimitAlertText.message(resetAt: usage?.resetAt)
                )
            }
            .store(in: &cancelBag)

        output.latestHistory
            .receive(on: DispatchQueue.main)
            .sink { [weak self] summary in
                self?.recentChip.isHidden = summary == nil
                if let summary { self?.recentChip.configure(summary) }
            }
            .store(in: &cancelBag)

        // 활성 타이머 수 — 0이어도 항상 표시한다(칩이 사라지면 홈이 허전해 보임).
        output.activeTimerCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.timerChip.setText("활성 타이머 \(count)")
            }
            .store(in: &cancelBag)
    }
}

// MARK: - Recent History Chip

/// 최근 식별 칩 — `⟲ 품목명 외 N`. 배경 Primary50 · 테두리 Primary100 1px · 캡슐, padding (8, 14), gap 6.
/// 품목명이 넘치면 말줄임하고 `외 N`은 남긴다(디자인 `g5naPt`) — DSChip 은 라벨이 하나라 따로 둔다.
private final class RecentHistoryChip: UIControl {

    private let nameLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.medium.font(size: 13)
        $0.textColor = DSColor.Primary._600
        $0.lineBreakMode = .byTruncatingTail
        $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private let othersLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.medium.font(size: 13)
        $0.textColor = DSColor.Primary._600
        $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        $0.setContentHuggingPriority(.required, for: .horizontal)
    }

    init() {
        super.init(frame: .zero)
        backgroundColor = DSColor.Primary._50
        layer.cornerRadius = 20
        layer.borderWidth = 1
        layer.borderColor = DSColor.Primary._100.cgColor

        let icon = UIImageView(image: DSIcon.history.uiImage).then {
            $0.tintColor = DSColor.Primary._500
            $0.contentMode = .scaleAspectFit
        }
        icon.snp.makeConstraints { $0.width.height.equalTo(14) }

        let stack = UIStackView(arrangedSubviews: [icon, nameLabel, othersLabel]).then {
            $0.axis = .horizontal
            $0.spacing = 6
            $0.alignment = .center
            $0.isUserInteractionEnabled = false
        }
        stack.setCustomSpacing(4, after: nameLabel)
        addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(8)
            $0.leading.trailing.equalToSuperview().inset(14)
        }
        accessibilityTraits = .button
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(_ summary: PillHistorySummaryModel) {
        nameLabel.text = summary.firstPillName
        othersLabel.text = summary.othersText
        othersLabel.isHidden = summary.othersText == nil
        accessibilityLabel = "최근 식별 \(summary.firstPillName) \(summary.othersText ?? "")"
    }
}
