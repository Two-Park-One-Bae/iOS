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

    private lazy var greetingStack = UIStackView(arrangedSubviews: [greetingLabel, roleLabel]).then {
        $0.axis = .vertical
        $0.spacing = 2
    }

    private let chipsStack = UIStackView().then {
        $0.axis = .horizontal
        $0.spacing = 8
    }

    private let cardsStack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 12
    }

    private let activityStack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 12
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
        contentStack.addArrangedSubview(makeActivitySection())
    }

    private func makeChipsRow() -> UIView {
        let wardChip = DSChip(text: "병동 다이어 2")
        let recentChip = DSChip(text: "최근 작업 9")
        let spacer = UIView()

        let stack = UIStackView(arrangedSubviews: [wardChip, recentChip, spacer]).then {
            $0.axis = .horizontal
            $0.spacing = 8
        }
        return stack
    }

    // 남은 횟수를 갱신해야 해서 프로퍼티로 유지한다.
    private let drugCard = DSListRow(
        icon: .search,
        title: "약물 식별",
        subtitle: "장기 처방약을 간편히 식별하고 성분 정보를 확인하세요."
    )

    private func makeCardsSection() -> UIView {
        drugCard.setIconBackground(DSColor.Primary._50)
        drugCard.setIconTint(DSColor.Primary._500)
        drugCard.onTap { [weak self] in self?.drugIdentifySubject.send() }

        let timerCard = DSListRow(
            icon: .clock,
            title: "처치 타이머",
            subtitle: "투약일 처치 시간을 체계적으로 관리하세요."
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

    private func makeActivitySection() -> UIView {
        let titleLabel = UILabel().then {
            $0.text = "최근 활동"
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 18)
            $0.textColor = DSColor.textPrimary
            $0.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }
        let moreBtn = UIButton(type: .system).then {
            $0.setTitle("전체보기", for: .normal)
            $0.titleLabel?.font = DSKitFontFamily.Pretendard.medium.font(size: 13)
            $0.setTitleColor(DSColor.Primary._500, for: .normal)
        }
        let headerRow = UIStackView(arrangedSubviews: [titleLabel, moreBtn]).then {
            $0.axis = .horizontal
            $0.alignment = .center
        }

        let row = DSListRow(icon: .search, title: "이부프로펜 200mg", subtitle: "오늘 오전 9:21")
        row.setChevronHidden(true)

        let stack = UIStackView(arrangedSubviews: [headerRow, row]).then {
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
            treatmentTimerTapped: treatmentTimerSubject.eraseToAnyPublisher()
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
    }
}
