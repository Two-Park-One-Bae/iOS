import UIKit
import Combine
import SnapKit
import Then
import DSKit
import Domain
import Core

// ⑧ 알약 수정 — 속성 카드(접힘/펼침 · 3단 조건 · 칸 색 · 되돌리기, NM-490) + 실시간 후보 + 선택/확인
//
// 후보 리스트를 UIStackView 로 매 응답마다 재생성하던 구조가 Severe Hang(UIScrollView.layoutSubviews
// + 대량 NSLayoutConstraint)을 유발해, 셀 재사용 UICollectionView 로 옮겼다.
// 섹션0 = 속성 카드(단일 셀), 섹션1 = 후보/로딩/빈상태 셀 + 헤더/푸터.
final class PillEditVC: UIViewController {

    // MARK: - Callbacks

    var onConfirm: ((PillCandidateModel) -> Void)?
    var onCancel: (() -> Void)?
    var onBackTapped: (() -> Void)?
    // 후보 ⓘ 탭 → 세부정보 진입 (pillCode, 허가상태). 세부 이미지는 상세 조회 응답에서 로드(NM-347).
    var onSelectDetail: ((String, LicenseStatus) -> Void)?
    // 후보 썸네일 탭 → 이미지 비교 뷰어 (NM-354). (candidate, 촬영 크롭, 소스 프레임(윈도우 좌표), 소스 이미지)
    var onSelectCompare: ((PillCandidateModel, UIImage?, CGRect, UIImage?) -> Void)?
    /// 조건이 바뀔 때마다 — Coordinator 가 알약별로 보관해 화면을 다시 열어도 이어지게 한다.
    var onConditionsChanged: ((PillConditions) -> Void)?

    // MARK: - Sections / State

    private enum Section: Int, CaseIterable { case attribute, candidates }
    private enum ListState { case loading, empty, failed, results([PillCandidateModel]) }

    // MARK: - Properties

    private let viewModel: PillEditViewModel
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private var cancelBag = Set<AnyCancellable>()

    private var listState: ListState = .loading
    private var selectedPillCode: String?
    private weak var header: CandidateHeaderView?
    private weak var truncatedFooter: CandidateTruncatedFooter?
    /// 헤더 개수 — 조회 중 · 실패면 nil(개수 없이 `후보`).
    private var summary: PillEditViewModel.CandidateSummary?

    /// 지금 열려 있는 편집(메뉴·입력 줄) — 이탈 계측(pill_flow_exit.editing_attribute)용.
    private var editingAttribute = "none"
    private var dismissMenu: (() -> Void)?
    /// 각인 입력 줄이 고치고 있는 면.
    private var editingFace: PillFace?
    /// 체류시간(`pill_confirm.dwell_ms`) 누적기 — Coordinator 가 소유해 화면이 다시 만들어져도 이어진다.
    /// 주입되지 않으면(데모 등) 시간은 0 으로 나간다.
    var dwellTracker: PillDwellTracker?

    // MARK: - UI

    private lazy var navBar = DSNavBar(title: "알약 \(viewModel.displayNumber) 수정").then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private lazy var collectionView = UICollectionView(
        frame: .zero, collectionViewLayout: makeLayout()
    ).then {
        $0.backgroundColor = DSColor.bgApp
        $0.alwaysBounceVertical = true
        $0.showsVerticalScrollIndicator = false
        $0.keyboardDismissMode = .interactive
        $0.dataSource = self
        $0.delegate = self
        $0.register(AttributeHostCell.self, forCellWithReuseIdentifier: AttributeHostCell.reuseID)
        $0.register(CandidateCell.self, forCellWithReuseIdentifier: CandidateCell.reuseID)
        $0.register(CandidateLoadingCell.self, forCellWithReuseIdentifier: CandidateLoadingCell.reuseID)
        $0.register(CandidateEmptyCell.self, forCellWithReuseIdentifier: CandidateEmptyCell.reuseID)
        $0.register(CandidateFailedCell.self, forCellWithReuseIdentifier: CandidateFailedCell.reuseID)
        $0.register(
            CandidateHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: CandidateHeaderView.reuseID
        )
        $0.register(
            CandidateTruncatedFooter.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: CandidateTruncatedFooter.reuseID
        )
    }

    // 속성 카드 — VC가 소유, 섹션0 셀에 호스팅된다(메뉴·입력 줄 상호작용은 VC가 소유).
    private lazy var attributeCardView = PillAttributeCardView(
        title: "알약 \(viewModel.displayNumber)",
        thumbnail: viewModel.thumbnail,
        conditions: viewModel.conditions,
        expanded: viewModel.startsExpanded
    )

    /// 키보드 위 각인 입력 줄. 화면에 보이지 않는 대리 필드의 inputAccessoryView 로 띄운 뒤
    /// 실제 입력은 줄 안의 필드로 넘긴다 — 면 카드 칸이 좁아 입력은 화면 폭에서 한다.
    private let imprintBar = ImprintInputBar()
    private lazy var imprintProxy = UITextField().then {
        $0.isHidden = true
        $0.inputAccessoryView = imprintBar
    }

    private let footer = UIView().then {
        $0.backgroundColor = DSColor.bgApp
        $0.layer.shadowColor = DSColor.textPrimary.cgColor
        $0.layer.shadowOpacity = 0.1
        $0.layer.shadowOffset = CGSize(width: 0, height: -4)
        $0.layer.shadowRadius = 16
    }
    private let cancelButton = SecondaryButton(title: "취소")
    private let confirmButton = PrimaryButton(title: "확인")
    /// 취소·확인 묶음 — 후보를 골라야 나타난다. UIStackView 의 arranged subview 라 숨기면 접힌다.
    private lazy var buttonsRow = UIStackView(arrangedSubviews: [cancelButton, confirmButton]).then {
        $0.axis = .horizontal
        $0.spacing = 10
        $0.distribution = .fillEqually
    }
    /// 고지 문구 (Guideline 1.4.1) — 선택 여부와 무관하게 항상 노출.
    private let disclaimerLabel = PillDisclaimer.makeLabel()

    // MARK: - Init

    init(viewModel: PillEditViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        setUI()
        setLayout()
        setActions()
        bind()
        viewDidLoadSubject.send(())
    }

    // MARK: - Setup

    private func setUI() {
        view.backgroundColor = DSColor.bgApp
        // 이탈 계측(pill_flow_exit)은 여기가 아니라 viewDidDisappear 에서 잡는다 —
        // 이 화면을 나가는 길이 백 버튼 말고도 [취소] 버튼·스와이프 백으로 여럿이기 때문.
        navBar.onBackTapped = { [weak self] in
            self?.onBackTapped?()
        }
        view.addSubview(imprintProxy)
        // footer 는 항상 보인다 — 고지가 들어 있어 선택 전에도 노출돼야 한다(⑧-a).
        // 후보를 골라야 나타나는 건 버튼뿐이라 buttonsRow 만 접어 둔다.
        buttonsRow.isHidden = true
    }

    private func setLayout() {
        view.addSubview(navBar)
        view.addSubview(collectionView)
        view.addSubview(footer)

        navBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
        }
        collectionView.snp.makeConstraints {
            $0.top.equalTo(navBar.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        setupFooter()
    }

    /*
     하단 footer — 버튼(선택 시) + 고지(항상).

     디자인상 고지는 footer 안, 버튼 '아래'에 있고 "⑧-a 진입 (선택 전)"에도 노출된다.
     그래서 footer 자체는 늘 띄워두고 buttonsRow 만 접는다. footer 를 통째로 숨기면
     선택 전에 고지가 사라진다.
     */
    private func setupFooter() {
        let stack = UIStackView(arrangedSubviews: [buttonsRow, disclaimerLabel]).then {
            $0.axis = .vertical
            $0.spacing = 10
        }
        footer.addSubview(stack)
        footer.snp.makeConstraints { $0.leading.trailing.bottom.equalToSuperview() }
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(12)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-28)
        }
    }

    // MARK: - Compositional Layout

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] index, _ in
            guard let section = Section(rawValue: index) else { return nil }
            switch section {
            case .attribute:
                return self?.makeAttributeSection()
            case .candidates:
                return self?.makeCandidateSection()
            }
        }
    }

    private func makeAttributeSection() -> NSCollectionLayoutSection {
        let size = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1), heightDimension: .estimated(320)
        )
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: size, repeatingSubitem: item, count: 1)
        let section = NSCollectionLayoutSection(group: group)
        // 하단 14 = 카드 → "후보" 헤더 간격(기존 스택뷰 spacing 14와 동일).
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 14, trailing: 20)
        return section
    }

    private func makeCandidateSection() -> NSCollectionLayoutSection {
        let size = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1), heightDimension: .estimated(64)
        )
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: size, repeatingSubitem: item, count: 1)
        let section = NSCollectionLayoutSection(group: group)
        // 칸끼리 붙여 흰 카드 하나로 보인다 — 구분선은 셀이 그린다.
        section.interGroupSpacing = 0
        // 상단 14 = "후보" 헤더 → 첫 후보 간격(헤더는 섹션 경계라 이 inset이 그 아래 여백이 됨).
        // 아래 여백 24 는 푸터(200개 초과 안내)가 갖는다 — 목록 → 안내 간격을 디자인(14 + 4)대로 두려고.
        section.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 0, trailing: 20)

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1), heightDimension: .estimated(24)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        let footerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1), heightDimension: .estimated(24)
        )
        let footer = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: footerSize,
            elementKind: UICollectionView.elementKindSectionFooter,
            alignment: .bottom
        )
        section.boundarySupplementaryItems = [header, footer]
        return section
    }

    // MARK: - Actions

    private func setActions() {
        attributeCardView.onAction = { [weak self] in self?.handle($0) }
        imprintBar.onSubmit = { [weak self] text in
            guard let self, let face = self.editingFace else { return }
            self.viewModel.submitImprint(text, on: face)
            self.closeImprintInput()
        }
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
    }

    @objc private func cancelTapped() { onCancel?() }
    @objc private func confirmTapped() {
        guard let selected = currentResults.first(where: { $0.pillCode == selectedPillCode }) else { return }
        // pill_confirm — 알약 1개 확정: 몇 번째 후보·수정 횟수·수정 속성·확정까지 체류시간.
        // 수동 추가 알약은 검출 모델과 무관해 제외(candidate_index 등 정확도 지표 오염 방지).
        if !viewModel.isManual {
            AppAnalytics.track(.pillConfirm(
                pillIndex: viewModel.pillIndex,
                // firstIndex 는 0 기반이라 +1 — 리포트에서 "1번째 후보"로 읽히게 맞춘다.
                // (바로 위 guard 가 같은 술어로 통과했으므로 nil 은 실제로 나오지 않는다.
                //  그래도 0 으로 떨어뜨려 두면 AnalyticsEvent 가 "unknown" 으로 드러내 준다)
                candidateIndex: currentResults.firstIndex(where: { $0.pillCode == selectedPillCode }).map { $0 + 1 } ?? 0,
                editCount: viewModel.editCount,
                editedAttrs: viewModel.editedAttrsJoined,
                dwellMs: dwellMs()
            ))
        }
        didConfirm = true
        onConfirm?(selected)
    }

    // MARK: - Analytics helpers

    /// 확정으로 나갔는지 — 확정은 pill_confirm 이 담당하므로 이탈 계측에서 제외한다.
    private var didConfirm = false

    /// 이탈 계측은 버튼 핸들러가 아니라 **화면이 실제로 사라질 때** 한 곳에서 잡는다.
    /// 백 버튼·[취소] 버튼·스와이프 백이 모두 pop 으로 수렴하므로 여기 하나로 전부 커버되고,
    /// 나중에 나가는 길이 늘어도 자동으로 따라온다.
    ///
    /// `isMovingFromParent`/`isBeingDismissed` 로 거르는 이유: 후보 세부정보·이미지 비교 뷰어를
    /// push 할 때도 viewDidDisappear 는 불리는데, 그건 이탈이 아니라 잠시 가려지는 것뿐이다.
    /// (앱 강제 종료·백그라운드 이탈은 여기로 안 들어온다 — 그건 원래도 못 잡던 경로다)
    /// 화면이 실제로 떠 있는 동안만 체류시간을 센다. 세부정보·비교 뷰어를 push 했다 돌아올 때도
    /// 여기로 다시 들어와 구간이 이어진다.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        dwellTracker?.resume(pillIndex: viewModel.pillIndex)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // 이탈이든 잠시 가려진 것이든 화면에서 사라지면 시계는 멈춘다.
        dwellTracker?.pause()
        guard isMovingFromParent || isBeingDismissed else { return }
        guard !didConfirm else { return }
        trackFlowExit()
    }

    private func trackFlowExit() {
        guard !viewModel.isManual else { return }   // 수동 추가 알약은 집계 제외
        AppAnalytics.track(.pillFlowExit(
            pillIndex: viewModel.pillIndex,
            editingAttribute: editingAttributeName,
            enteredValues: viewModel.enteredValuesSummary,
            editCount: viewModel.editCount
        ))
    }

    private var editingAttributeName: String { editingAttribute }

    private func dwellMs() -> Int {
        dwellTracker?.elapsedMs(pillIndex: viewModel.pillIndex) ?? 0
    }

    // MARK: - Bind

    private func bind() {
        let output = viewModel.transform(
            input: PillEditViewModel.Input(viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher())
        )
        output.candidates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] candidates in self?.renderCandidates(candidates) }
            .store(in: &cancelBag)

        // 조건이 바뀌면 카드를 다시 그리고(칸 색 · 값), Coordinator 에 알린다.
        viewModel.conditionsSubject
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] conditions in
                guard let self else { return }
                self.attributeCardView.update(conditions: conditions)
                self.relayoutCard()
                self.onConditionsChanged?(conditions)
            }
            .store(in: &cancelBag)

        // 개수는 목록보다 먼저 온다(ViewModel) — 목록을 다시 그릴 때 헤더 · 끝 안내가 함께 반영된다.
        output.summary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.summary = $0 }
            .store(in: &cancelBag)

        output.searchFailed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                self.listState = .failed
                self.selectedPillCode = nil
                self.summary = nil
                self.collectionView.reloadSections(IndexSet(integer: Section.candidates.rawValue))
                self.updateFooterVisibility()
            }
            .store(in: &cancelBag)

        // 검색 시작 시에만 로딩 셀로 전환. 응답이 오면 candidates 싱크가 결과/빈상태를 그린다.
        output.isSearching
            .receive(on: DispatchQueue.main)
            .sink { [weak self] searching in
                guard let self, searching else { return }
                self.listState = .loading
                self.selectedPillCode = nil
                self.summary = nil
                self.collectionView.reloadSections(IndexSet(integer: Section.candidates.rawValue))
                self.updateFooterVisibility()
            }
            .store(in: &cancelBag)
    }

    // MARK: - Candidates

    /// 서버가 200개에서 자른 결과일 때만 목록 끝 안내.
    private var showsTruncatedNotice: Bool {
        !currentResults.isEmpty && summary?.truncated == true
    }

    private var currentResults: [PillCandidateModel] {
        if case .results(let c) = listState { return c }
        return []
    }

    /// 목록 · 빈 상태를 그린다. 이어 받기로 뒤에 붙어도 고른 후보가 목록에 있으면 선택을 유지한다.
    private func renderCandidates(_ candidates: [PillCandidateModel]) {
        listState = candidates.isEmpty ? .empty : .results(candidates)
        if let selected = selectedPillCode, !candidates.contains(where: { $0.pillCode == selected }) {
            selectedPillCode = nil
        }
        collectionView.reloadSections(IndexSet(integer: Section.candidates.rawValue))
        updateFooterVisibility()
    }

    private func selectCandidate(pillCode: String) {
        selectedPillCode = pillCode
        // 리로드 대신 보이는 후보 셀의 선택 상태만 갱신(썸네일 재로드·깜빡임 방지).
        for case let cell as CandidateCell in collectionView.visibleCells {
            cell.setSelected(cell.pillCode == pillCode)
        }
        updateFooterVisibility()
    }

    private func updateFooterVisibility() {
        let hasSelection = selectedPillCode != nil
        // 고지는 항상 보여야 하므로(⑧-a 선택 전) footer 가 아니라 버튼만 접는다.
        setHidden(buttonsRow, !hasSelection)
        // 접힘/펼침이 반영된 높이를 읽어야 스크롤 하단 여백이 맞는다.
        view.layoutIfNeeded()
        let inset = footer.frame.height
        if collectionView.contentInset.bottom != inset { collectionView.contentInset.bottom = inset }
    }

    private func setHidden(_ view: UIView, _ hidden: Bool) {
        if view.isHidden != hidden { view.isHidden = hidden }
    }

}

// MARK: - UICollectionViewDataSource

extension PillEditVC: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .attribute:
            return 1
        case .candidates:
            switch listState {
            case .loading, .empty, .failed: return 1
            case .results(let c): return c.count
            }
        case .none:
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section) {
        case .attribute:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: AttributeHostCell.reuseID, for: indexPath
            ) as! AttributeHostCell
            cell.host(attributeCardView)
            return cell

        case .candidates:
            switch listState {
            case .loading:
                return collectionView.dequeueReusableCell(
                    withReuseIdentifier: CandidateLoadingCell.reuseID, for: indexPath
                )
            case .empty:
                return collectionView.dequeueReusableCell(
                    withReuseIdentifier: CandidateEmptyCell.reuseID, for: indexPath
                )
            case .failed:
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: CandidateFailedCell.reuseID, for: indexPath
                ) as! CandidateFailedCell
                cell.onRetry = { [weak self] in self?.viewModel.retry() }
                return cell
            case .results(let candidates):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: CandidateCell.reuseID, for: indexPath
                ) as! CandidateCell
                let candidate = candidates[indexPath.item]
                cell.configure(
                    candidate: candidate,
                    selected: candidate.pillCode == selectedPillCode,
                    position: .init(isFirst: indexPath.item == 0, isLast: indexPath.item == candidates.count - 1)
                )
                cell.onInfoTap = { [weak self] in
                    self?.onSelectDetail?(candidate.pillCode, candidate.licenseStatus)
                }
                cell.onThumbnailTap = { [weak self, weak cell] in
                    guard let self, let cell else { return }
                    let iv = cell.thumbnailView
                    // 윈도우 좌표계 프레임 — 확대 트랜지션 소스.
                    let sourceFrame = iv.convert(iv.bounds, to: nil)
                    self.onSelectCompare?(candidate, self.viewModel.thumbnail, sourceFrame, iv.image)
                }
                return cell
            }

        case .none:
            return UICollectionViewCell()
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind, withReuseIdentifier: CandidateHeaderView.reuseID, for: indexPath
            ) as! CandidateHeaderView
            header.configure(count: summary?.count, truncated: summary?.truncated ?? false)
            self.header = header
            return header
        }
        let footer = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: CandidateTruncatedFooter.reuseID, for: indexPath
        ) as! CandidateTruncatedFooter
        footer.setVisible(showsTruncatedNotice)
        truncatedFooter = footer
        return footer
    }
}

// MARK: - UICollectionViewDelegate

extension PillEditVC: UICollectionViewDelegate {

    // 후보 목록 끝(마지막 3개 이내)에 다다르면 다음 페이지를 미리 요청(커서 페이지네이션).
    // 중복 호출·마지막 페이지 가드는 viewModel.loadMore 내부에서 처리한다.
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard Section(rawValue: indexPath.section) == .candidates,
              case .results(let candidates) = listState,
              indexPath.item >= candidates.count - 3 else { return }
        viewModel.loadMore()
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard Section(rawValue: indexPath.section) == .candidates else { return false }
        if case .results = listState { return true }
        return false
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? CandidateCell,
              let code = cell.pillCode else { return }
        selectCandidate(pillCode: code)
    }
}

// MARK: - 속성 카드 · 메뉴 · 각인 입력 (NM-513)

private extension PillEditVC {

    func handle(_ action: PillAttributeCardView.Action) {
        switch action {
        case .toggleExpanded:
            attributeCardView.setExpanded(!attributeCardView.isExpanded)
            relayoutCard()

        case .colors(let anchor):
            let userColors = viewModel.conditions.colors.userValue ?? []
            let menu = ConditionGridMenuView(
                items: Self.colorOrder.map(Self.colorItem),
                selected: Set(userColors.map(\.rawValue)),
                multiple: true,
                modelPreview: modelColorPreview()
            )
            menu.onSelect = { [weak self, weak menu] id in
                guard let self, let menu else { return }
                // 색은 여러 개 고른다 — 칸을 누를 때마다 바로 반영하고 메뉴는 열어 둔다. `전체` 는 모두 풀고 닫는다.
                self.viewModel.setColors(menu.selectedIDs.compactMap(PillColorModel.init(rawValue:)))
                if id == nil { self.dismissMenu?() }
            }
            showMenu(menu, below: anchor, fullWidth: true, editing: "color")

        case .shape(let anchor):
            let menu = ConditionGridMenuView(
                items: Self.shapeOrder.map(Self.shapeItem),
                selected: Set([viewModel.conditions.shape.userValue?.rawValue].compactMap { $0 }),
                multiple: false,
                modelPreview: viewModel.conditions.model.shape.map(Self.shapeIcon)
            )
            menu.onSelect = { [weak self] id in
                self?.viewModel.setShape(id.flatMap(PillShapeModel.init(rawValue:)))
                self?.dismissMenu?()
            }
            showMenu(menu, below: anchor, fullWidth: true, editing: "shape")

        case .formulation(let anchor):
            let menu = ConditionGridMenuView(
                items: Self.formulationOrder.map(Self.formulationItem),
                selected: Set([viewModel.conditions.formulation.userValue?.rawValue].compactMap { $0 }),
                multiple: false,
                modelPreview: viewModel.conditions.model.formulation.map(Self.formulationIcon)
            )
            menu.onSelect = { [weak self] id in
                self?.viewModel.setFormulation(id.flatMap(PillFormulationModel.init(rawValue:)))
                self?.dismissMenu?()
            }
            showMenu(menu, below: anchor, fullWidth: true, editing: "formulation")

        case let .imprintMenu(face, anchor):
            let current = faceConditions(face).imprint
            let selected: Int
            switch current {
            case .all:   selected = 0
            case .none:  selected = 1
            case .value: selected = 2
            }
            let menu = ConditionListMenuView(options: ["전체", "없음", "입력"], selectedIndex: selected)
            menu.onSelect = { [weak self] index in
                guard let self else { return }
                self.dismissMenu?()
                switch index {
                case 0: self.viewModel.setImprint(.all, on: face)
                case 1: self.viewModel.setImprint(.none, on: face)
                default: self.openImprintInput(face)
                }
            }
            showMenu(menu, below: anchor, fullWidth: false, editing: "imprint")

        case .imprintField(let face):
            openImprintInput(face)

        case .revertImprint(let face):
            viewModel.revertImprint(on: face)

        case let .dividingLine(face, anchor):
            let current = faceConditions(face).dividingLine
            let selectedID: String?
            switch current {
            case .all:                selectedID = nil
            case .none:               selectedID = "none"
            case .value(let line):    selectedID = line.rawValue
            }
            let menu = ConditionGridMenuView(
                items: [
                    ConditionGridItem(id: "none", label: "없음", icon: Self.dividingIcon(nil)),
                    ConditionGridItem(id: DividingLineModel.plus.rawValue, label: "(+)형", icon: Self.dividingIcon(.plus)),
                    ConditionGridItem(id: DividingLineModel.minus.rawValue, label: "(−)형", icon: Self.dividingIcon(.minus)),
                ],
                selected: Set([selectedID].compactMap { $0 }),
                multiple: false,
                modelPreview: nil   // 구분선은 모델이 없다
            )
            menu.onSelect = { [weak self] id in
                let condition: DividingLineCondition
                switch id {
                case nil:    condition = .all
                case "none": condition = .none
                default:     condition = .value(DividingLineModel(rawValue: id ?? "") ?? .unknown)
                }
                self?.viewModel.setDividingLine(condition, on: face)
                self?.dismissMenu?()
            }
            showMenu(menu, below: anchor, fullWidth: true, editing: "dividing_line")

        case let .mark(face, anchor):
            let current = faceConditions(face).mark
            let selected: Int
            switch current {
            case .all:     selected = 0
            case .none:    selected = 1
            case .present: selected = 2
            }
            let menu = ConditionListMenuView(options: ["전체", "없음", "있음"], selectedIndex: selected)
            menu.onSelect = { [weak self] index in
                guard let self else { return }
                self.dismissMenu?()
                // 메뉴에서 고른 `있음` 은 모델값이 아니라 사용자값이다.
                let condition: MarkCondition = [MarkCondition.all, .none, .present(source: .user)][index]
                self.viewModel.setMark(condition, on: face)
            }
            showMenu(menu, below: anchor, fullWidth: false, editing: "mark")
        }
    }

    func faceConditions(_ face: PillFace) -> FaceConditions {
        face == .front ? viewModel.conditions.front : viewModel.conditions.back
    }

    /// 카드 높이가 바뀌면(펼침 · 입력칸 등장) 섹션0 셀 self-sizing 을 다시 잰다.
    /// 조합형 레이아웃은 내용만 바뀐 셀을 다시 재지 않는다 — reconfigure 로 셀 크기를 다시 묻는다.
    /// (호스트 셀은 같은 카드를 다시 붙이지 않아 퍼스트 리스폰더가 유지된다.)
    func relayoutCard() {
        collectionView.performBatchUpdates {
            collectionView.reconfigureItems(at: [IndexPath(item: 0, section: Section.attribute.rawValue)])
        }
    }

    func showMenu(_ menu: UIView, below anchor: UIView, fullWidth: Bool, editing: String) {
        dismissMenu?()
        editingAttribute = editing
        dismissMenu = ConditionMenuPresenter.present(menu, below: anchor, in: view, fullWidth: fullWidth) { [weak self] in
            self?.dismissMenu = nil
            self?.editingAttribute = "none"
        }
    }

    // MARK: 각인 입력 줄

    func openImprintInput(_ face: PillFace) {
        editingFace = face
        editingAttribute = "imprint"
        let text: String
        if case .value(let value, _) = faceConditions(face).imprint { text = value } else { text = "" }
        imprintBar.prepare(faceTitle: face == .front ? "앞면" : "뒷면", text: text)
        imprintProxy.becomeFirstResponder()
        // 대리 필드로 키보드 + 입력 줄을 띄운 다음, 실제 입력은 줄 안의 필드로 넘긴다.
        DispatchQueue.main.async { [weak self] in self?.imprintBar.field.becomeFirstResponder() }
    }

    /// 확인하지 않고 닫으면 값은 그대로다 — 조건은 확인했을 때만 바뀐다.
    func closeImprintInput() {
        editingFace = nil
        editingAttribute = "none"
        // 입력 줄의 필드는 키보드 창에 붙어 있어 view.endEditing 이 닿지 않는다 — 직접 내린다.
        imprintBar.field.resignFirstResponder()
        imprintProxy.resignFirstResponder()
    }

    // MARK: 메뉴 칸 그림

    /// 메뉴 칸 순서 — 디자인 격자(4열) 그대로.
    static let colorOrder: [PillColorModel] = [
        .white, .yellow, .orange, .pink, .red, .brown, .lightGreen, .green,
        .teal, .blue, .navy, .magenta, .purple, .gray, .black, .colorless,
    ]
    static let shapeOrder: [PillShapeModel] = [
        .round, .oval, .oblong, .semicircle, .triangle, .square, .diamond, .pentagon, .hexagon, .octagon, .other,
    ]
    static let formulationOrder: [PillFormulationModel] = [.tablet, .hardCapsule, .softCapsule, .other]

    static func colorItem(_ color: PillColorModel) -> ConditionGridItem {
        let dot = UIView().then {
            $0.backgroundColor = color.swatchColor ?? DSColor.Neutral._0
            $0.layer.cornerRadius = 14
            $0.clipsToBounds = true
            $0.snp.makeConstraints { $0.width.height.equalTo(28) }
        }
        if color == .colorless {
            // 무색 — 흰 원에 사선.
            let slash = CAShapeLayer()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 5, y: 23))
            path.addLine(to: CGPoint(x: 23, y: 5))
            slash.path = path.cgPath
            slash.strokeColor = DSColor.Neutral._400.cgColor
            slash.lineWidth = 1.5
            dot.layer.addSublayer(slash)
        }
        return ConditionGridItem(id: color.rawValue, label: color.menuLabel, icon: dot) { selected in
            dot.layer.borderWidth = selected ? 2 : 1
            dot.layer.borderColor = (selected ? DSColor.Warning._700 : DSColor.Neutral._300).cgColor
        }
    }

    static func shapeItem(_ shape: PillShapeModel) -> ConditionGridItem {
        let glyph = shapeIcon(shape)
        return ConditionGridItem(id: shape.rawValue, label: shape.menuLabel, icon: glyph) { selected in
            glyph.setTint(selected ? DSColor.Warning._700 : DSColor.textSecondary)
        }
    }

    static func formulationItem(_ formulation: PillFormulationModel) -> ConditionGridItem {
        let icon = formulationIcon(formulation)
        return ConditionGridItem(id: formulation.rawValue, label: formulation.displayName, icon: icon) { selected in
            let tint = selected ? DSColor.Warning._700 : DSColor.textSecondary
            (icon as? FormulationIconView)?.setTint(tint)
            icon.tintColor = tint
        }
    }

    /// 메뉴 칸 · '사진 기준' 모양 그림 — 32×28 칸에 디자인 크기 그대로.
    static func shapeIcon(_ shape: PillShapeModel) -> ShapeGlyphView {
        ShapeGlyphView(shape: shape, atDesignSize: true).then {
            $0.setTint(DSColor.textSecondary)
            $0.snp.makeConstraints { $0.width.equalTo(32); $0.height.equalTo(28) }
        }
    }

    /// 메뉴 칸 · '사진 기준' 제형 그림 (28×24). `기타` 는 말줄임 아이콘(lucide ellipsis).
    static func formulationIcon(_ formulation: PillFormulationModel) -> UIView {
        guard formulation != .other, formulation != .unknown else {
            return UIView().then { box in
                box.tintColor = DSColor.textSecondary
                let dots = UIImageView(image: DSIcon.moreHorizontal.uiImage).then { $0.contentMode = .scaleAspectFit }
                box.addSubview(dots)
                dots.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.equalTo(16) }
                box.snp.makeConstraints { $0.width.equalTo(28); $0.height.equalTo(24) }
            }
        }
        return FormulationIconView(formulation: formulation).then {
            $0.setTint(DSColor.textSecondary)
            $0.snp.makeConstraints { $0.width.equalTo(formulation == .tablet ? 24 : 28); $0.height.equalTo(24) }
        }
    }

    static func dividingIcon(_ line: DividingLineModel?) -> UIView {
        DividingLineGlyphView(line: line, tint: DSColor.Neutral._700).then {
            $0.snp.makeConstraints { $0.width.height.equalTo(24) }
        }
    }

    /// 색 메뉴 `전체` 옆 '사진 기준' — 모델이 잰 색.
    func modelColorPreview() -> UIView? {
        let colors = viewModel.conditions.model.colorHexes.compactMap(UIColor.init(pillHex:))
        guard !colors.isEmpty else { return nil }
        return ColorPieView(colors: colors).then { $0.snp.makeConstraints { $0.width.height.equalTo(20) } }
    }
}

private extension PillColorModel {
    /// 메뉴 라벨 — 디자인 표기(자주 · 무색).
    var menuLabel: String {
        switch self {
        case .magenta:   return "자주"
        case .colorless: return "무색"
        default:         return displayName
        }
    }
}

private extension PillShapeModel {
    var menuLabel: String {
        self == .diamond ? "마름모형" : displayName
    }
}
