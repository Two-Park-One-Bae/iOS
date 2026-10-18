import UIKit
import Combine
import SnapKit
import Then
import DSKit
import Domain

// 알약 탭 — 촬영 버튼 + 식별 기록 목록 (NM-552, 디자인 `Oqopb` · 기록 없음 `f7D3Y`).
final class PillHistoryListVC: UIViewController {

    // MARK: - Callbacks

    var onCaptureTapped: (() -> Void)?
    var onSelectHistory: ((PillHistorySummaryModel) -> Void)?

    // MARK: - Dependencies

    private let viewModel: PillHistoryListViewModel
    private let viewWillAppearSubject = PassthroughSubject<Void, Never>()
    private let retrySubject = PassthroughSubject<Void, Never>()
    private let loadMoreSubject = PassthroughSubject<Void, Never>()
    private var cancelBag = Set<AnyCancellable>()
    private var canLoadMore = false

    // MARK: - UI

    private let titleLabel = UILabel().then {
        $0.text = "알약 식별"
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 24)
        $0.textColor = DSColor.textPrimary
    }

    private let usageLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
        $0.textColor = DSColor.textSecondary
    }

    private let scrollView = UIScrollView().then {
        $0.showsVerticalScrollIndicator = false
        $0.alwaysBounceVertical = true
    }

    private let contentStack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 12
    }

    /// 기록 없음 · 불러오기 실패 · 첫 조회 중 — 목록 대신 가운데에 둔다
    private let stateContainer = UIView()

    private let captureButton = UIButton(type: .system).then {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = DSColor.Primary._500
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.image = DSIcon.camera.uiImage
        $0.configuration = config
        $0.layer.shadowColor = DSColor.Primary._600.cgColor
        $0.layer.shadowOpacity = 0.3
        $0.layer.shadowOffset = CGSize(width: 0, height: 6)
        $0.layer.shadowRadius = 10
        $0.accessibilityLabel = "촬영"
    }

    // MARK: - Init

    init(viewModel: PillHistoryListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = DSColor.bgApp
        setLayout()
        bind()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewWillAppearSubject.send(())
    }

    // MARK: - Layout

    private func setLayout() {
        let header = UIStackView(arrangedSubviews: [titleLabel, usageLabel]).then {
            $0.axis = .vertical
            $0.spacing = 4
        }
        let sectionTitle = UILabel().then {
            $0.text = "식별 기록"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 15)
            $0.textColor = DSColor.textPrimary
        }

        [header, sectionTitle, scrollView, stateContainer, captureButton].forEach(view.addSubview)
        scrollView.addSubview(contentStack)
        scrollView.delegate = self

        header.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        sectionTitle.snp.makeConstraints {
            $0.top.equalTo(header.snp.bottom).offset(20)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        scrollView.snp.makeConstraints {
            $0.top.equalTo(sectionTitle.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide)
        }
        contentStack.snp.makeConstraints {
            $0.top.equalTo(scrollView.contentLayoutGuide)
            $0.leading.trailing.equalTo(scrollView.frameLayoutGuide).inset(20)
            // 촬영 버튼 높이만큼 여백 — 마지막 기록이 버튼에 가려지지 않게
            $0.bottom.equalTo(scrollView.contentLayoutGuide).inset(96)
        }
        stateContainer.snp.makeConstraints { $0.edges.equalTo(scrollView) }
        captureButton.snp.makeConstraints {
            $0.width.height.equalTo(56)
            $0.trailing.equalToSuperview().inset(20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(20)
        }
        captureButton.addAction(UIAction { [weak self] _ in self?.onCaptureTapped?() }, for: .touchUpInside)
    }

    // MARK: - Bind

    private func bind() {
        let output = viewModel.transform(input: .init(
            viewWillAppear: viewWillAppearSubject.eraseToAnyPublisher(),
            retry: retrySubject.eraseToAnyPublisher(),
            loadMore: loadMoreSubject.eraseToAnyPublisher()
        ))

        output.state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.render($0) }
            .store(in: &cancelBag)

        output.usage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] usage in
                // 값을 모르면 줄을 비운다 — 홈 카드처럼 막을지는 서버가 판정한다.
                self?.usageLabel.text = usage?.remainingText
                self?.usageLabel.textColor = (usage?.isExhausted ?? false) ? DSColor.Error._600 : DSColor.textSecondary
            }
            .store(in: &cancelBag)
    }

    // MARK: - Render

    private func render(_ state: PillHistoryListViewModel.State) {
        stateContainer.subviews.forEach { $0.removeFromSuperview() }
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        switch state {
        case .loading:
            canLoadMore = false
            showInState(DSLoading(text: ""))
        case .empty:
            canLoadMore = false
            showInState(makeEmptyView())
        case .failed:
            canLoadMore = false
            showInState(makeFailedView(message: "기록을 불러오지 못했어요") { [weak self] in
                self?.retrySubject.send(())
            })
        case let .loaded(sections, footer):
            stateContainer.isHidden = true
            scrollView.isHidden = false
            canLoadMore = footer == .none
            for section in sections {
                contentStack.addArrangedSubview(makeDateLabel(section.title))
                contentStack.addArrangedSubview(makeGroupCard(section.items))
            }
            if let footerView = makeFooter(footer) {
                contentStack.addArrangedSubview(footerView)
            }
        }
    }

    private func showInState(_ content: UIView) {
        scrollView.isHidden = true
        stateContainer.isHidden = false
        stateContainer.addSubview(content)
        content.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(20)
        }
    }

    // MARK: - Views

    private func makeDateLabel(_ text: String) -> UIView {
        UILabel().then {
            $0.text = text
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 12)
            $0.textColor = DSColor.textTertiary
        }
    }

    /// 같은 날 기록을 한 카드에 묶는다 — 행 사이 Neutral100 1px 구분선.
    private func makeGroupCard(_ items: [PillHistorySummaryModel]) -> UIView {
        let card = UIView().then {
            $0.backgroundColor = DSColor.surface
            $0.layer.cornerRadius = 14
            $0.layer.shadowColor = DSColor.textPrimary.cgColor
            $0.layer.shadowOpacity = 0.04
            $0.layer.shadowOffset = CGSize(width: 0, height: 1)
            $0.layer.shadowRadius = 6
        }
        let rows = UIStackView().then { $0.axis = .vertical }
        for (index, item) in items.enumerated() {
            rows.addArrangedSubview(makeRow(item))
            if index < items.count - 1 {
                let divider = UIView().then { $0.backgroundColor = DSColor.Neutral._100 }
                divider.snp.makeConstraints { $0.height.equalTo(1) }
                rows.addArrangedSubview(divider)
            }
        }
        card.addSubview(rows)
        rows.snp.makeConstraints { $0.edges.equalToSuperview() }
        return card
    }

    /// 첫 품목명 + `외 N` · 식별 시각 · chevron. 품목명이 넘치면 말줄임하고 `외 N`과 시각은 남긴다.
    private func makeRow(_ item: PillHistorySummaryModel) -> UIView {
        let name = UILabel().then {
            $0.text = item.firstPillName
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 15)
            $0.textColor = DSColor.textPrimary
            $0.lineBreakMode = .byTruncatingTail
            $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        let others = UILabel().then {
            $0.text = item.othersText
            $0.isHidden = item.othersText == nil
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
            $0.textColor = DSColor.textSecondary
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            $0.setContentHuggingPriority(.required, for: .horizontal)
        }
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let time = UILabel().then {
            $0.text = item.identifiedAt.map(PillHistoryDateText.time)
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
            $0.textColor = DSColor.textSecondary
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            $0.setContentHuggingPriority(.required, for: .horizontal)
        }
        let chevron = UIImageView(image: DSIcon.chevronRight.uiImage).then {
            $0.tintColor = DSColor.textTertiary
            $0.contentMode = .scaleAspectFit
        }
        chevron.snp.makeConstraints { $0.width.height.equalTo(16) }

        let nameRow = UIStackView(arrangedSubviews: [name, others]).then {
            $0.axis = .horizontal
            $0.spacing = 6
            $0.alignment = .center
        }
        let row = UIStackView(arrangedSubviews: [nameRow, spacer, time, chevron]).then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.alignment = .center
            $0.isLayoutMarginsRelativeArrangement = true
            $0.layoutMargins = UIEdgeInsets(top: 15, left: 14, bottom: 15, right: 14)
        }

        let button = UIButton(type: .system)
        button.addAction(UIAction { [weak self] _ in self?.onSelectHistory?(item) }, for: .touchUpInside)
        row.addSubview(button)
        button.snp.makeConstraints { $0.edges.equalToSuperview() }
        return row
    }

    private func makeFooter(_ footer: PillHistoryListViewModel.Footer) -> UIView? {
        switch footer {
        case .none:
            return nil
        case .loadingMore:
            let spinner = UIActivityIndicatorView(style: .medium).then { $0.startAnimating() }
            spinner.snp.makeConstraints { $0.height.equalTo(44) }
            return spinner
        case .loadMoreFailed:
            return makeFailedView(message: "불러오지 못했어요") { [weak self] in
                self?.loadMoreSubject.send(())
            }
        case .end(let reachedCap):
            guard reachedCap else { return nil }
            return UILabel().then {
                $0.text = "최근 100건까지 보관해요"
                $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
                $0.textColor = DSColor.textTertiary
                $0.textAlignment = .center
            }
        }
    }

    private func makeEmptyView() -> UIView {
        let iconBackground = UIView().then {
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = 32
        }
        let icon = UIImageView(image: DSIcon.history.uiImage).then {
            $0.tintColor = DSColor.textTertiary
            $0.contentMode = .scaleAspectFit
        }
        iconBackground.addSubview(icon)
        iconBackground.snp.makeConstraints { $0.width.height.equalTo(64) }
        icon.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.height.equalTo(30)
        }
        let label = UILabel().then {
            $0.text = "아직 식별 기록이 없어요"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 15)
            $0.textColor = DSColor.textPrimary
            $0.textAlignment = .center
        }
        return UIStackView(arrangedSubviews: [iconBackground, label]).then {
            $0.axis = .vertical
            $0.spacing = 14
            $0.alignment = .center
        }
    }

    /// 불러오기 실패 — 문구 + `다시 시도`. 촬영 버튼은 그대로 쓸 수 있다.
    private func makeFailedView(message: String, retry: @escaping () -> Void) -> UIView {
        let label = UILabel().then {
            $0.text = message
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 14)
            $0.textColor = DSColor.textSecondary
            $0.textAlignment = .center
        }
        let button = TextButton(title: "다시 시도")
        button.addAction(UIAction { _ in retry() }, for: .touchUpInside)
        return UIStackView(arrangedSubviews: [label, button]).then {
            $0.axis = .vertical
            $0.spacing = 4
            $0.alignment = .center
        }
    }
}

// MARK: - UIScrollViewDelegate

extension PillHistoryListVC: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 끝에서 한 화면 남짓 남았을 때 다음 묶음을 받는다.
        let remaining = scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.bounds.height
        guard canLoadMore, remaining < scrollView.bounds.height else { return }
        canLoadMore = false
        loadMoreSubject.send(())
    }
}
