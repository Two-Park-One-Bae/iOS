import UIKit
import Combine
import SnapKit
import Then
import DSKit
import Domain
import Core

// ⑧ 알약 수정 — 속성 편집(색상/모양/제형/각인 인라인 펼침) + 실시간 후보 + 선택/확인
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

    // MARK: - Sections / State

    private enum Section: Int, CaseIterable { case attribute, candidates }
    private enum ListState { case loading, empty, results([PillCandidateModel]) }

    // MARK: - Properties

    private let viewModel: PillEditViewModel
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private var cancelBag = Set<AnyCancellable>()

    private var listState: ListState = .loading
    private var selectedPillCode: String?
    private weak var hintFooter: SelectHintFooter?

    private enum Panel { case none, color, shape, formulation, imprint }
    private var openPanel: Panel = .none
    /// 체류시간(`pill_confirm.dwell_ms`) 누적기 — Coordinator 가 소유해 화면이 다시 만들어져도 이어진다.
    /// 주입되지 않으면(데모 등) 시간은 0 으로 나간다.
    var dwellTracker: PillDwellTracker?

    // MARK: - UI

    private lazy var navBar = DSNavBar(title: "알약 \(viewModel.pillIndex) 수정").then {
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
        $0.register(
            CandidateHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: CandidateHeaderView.reuseID
        )
        $0.register(
            SelectHintFooter.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: SelectHintFooter.reuseID
        )
    }

    // 속성 카드 — VC가 소유, 섹션0 셀에 호스팅된다(칩·패널·각인 필드 상호작용은 VC가 계속 소유).
    private lazy var attributeCardView = makeAttributeCard()

    private let colorChip = AttributeChipButton()
    private let shapeChip = AttributeChipButton()
    private let formulationChip = AttributeChipButton()

    private let imprintSummary = ImprintSummaryView()
    private let imprintChevron = UIImageView().then {
        $0.image = UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
        $0.tintColor = DSColor.textTertiary
        $0.contentMode = .scaleAspectFit
    }

    private let colorPanel = ColorPickerPanel()
    private let colorDivider = PillEditVC.makeDividerLine()
    private let transparencyRow = TransparencyRowView()
    private let shapePanel = ShapePickerPanel()
    private let formulationPanel = FormulationPickerPanel()
    private lazy var imprintPanel = ImprintEditorPanel(front: viewModel.front, back: viewModel.back)

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
        refreshChips()
        colorPanel.setSelected(viewModel.colors)
        shapePanel.setSelected(viewModel.shape)
        formulationPanel.setSelected(viewModel.formulation)
        transparencyRow.setOn(viewModel.isTransparent)
        imprintSummary.update(front: viewModel.front, back: viewModel.back)
        // 각인 수정은 화면 진입 시 기본으로 펼쳐 둔다(나머지 패널은 접힘). 이후 토글은 togglePanel이 처리.
        openPanel = .imprint
        [colorPanel, colorDivider, transparencyRow, shapePanel, formulationPanel].forEach { $0.isHidden = true }
        imprintPanel.isHidden = false
        imprintChevron.transform = CGAffineTransform(rotationAngle: .pi)
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
        section.interGroupSpacing = 8
        // 상단 14 = "후보" 헤더 → 첫 후보 간격(헤더는 섹션 경계라 이 inset이 그 아래 여백이 됨).
        section.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 24, trailing: 20)

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

    // MARK: - Attribute Card

    private func makeAttributeCard() -> UIView {
        let card = UIView().then {
            $0.backgroundColor = DSColor.Neutral._0
            $0.layer.cornerRadius = 16
            $0.layer.masksToBounds = false
            $0.layer.shadowColor = DSColor.textPrimary.cgColor
            $0.layer.shadowOpacity = 0.04
            $0.layer.shadowOffset = CGSize(width: 0, height: 1)
            $0.layer.shadowRadius = 6
        }

        // Pill Header
        let crop = UIImageView().then {
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = 10
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFit
            $0.image = viewModel.thumbnail
        }
        crop.snp.makeConstraints { $0.width.height.equalTo(48) }
        let hTitle = UILabel().then {
            $0.text = "알약 \(viewModel.pillIndex)"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 15)
            $0.textColor = DSColor.textPrimary
        }
        let hSub = UILabel().then {
            $0.text = "속성을 수정하면 후보가 바뀌어요"
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
            $0.textColor = DSColor.textTertiary
        }
        let hText = UIStackView(arrangedSubviews: [hTitle, hSub]).then { $0.axis = .vertical; $0.spacing = 2 }
        let header = UIStackView(arrangedSubviews: [crop, hText]).then {
            $0.axis = .horizontal; $0.spacing = 12; $0.alignment = .center
        }

        // 속성 Row
        let attrLabel = makeRowLabel("속성")
        let chipsRow = UIStackView(arrangedSubviews: [attrLabel, colorChip, shapeChip, formulationChip, UIView()]).then {
            $0.axis = .horizontal; $0.spacing = 6; $0.alignment = .center
        }

        // 각인 Row
        let imprintRow = UIStackView(arrangedSubviews: [imprintSummary, imprintChevron]).then {
            $0.axis = .horizontal; $0.spacing = 10; $0.alignment = .center
        }
        imprintChevron.snp.makeConstraints { $0.width.height.equalTo(18) }
        let imprintTap = UIControl()
        imprintTap.addSubview(imprintRow)
        imprintRow.snp.makeConstraints { $0.top.bottom.equalToSuperview().inset(10); $0.leading.trailing.equalToSuperview() }
        imprintRow.isUserInteractionEnabled = false
        imprintTap.addAction(UIAction { [weak self] _ in self?.togglePanel(.imprint) }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            header, makeDivider(),
            chipsRow, colorPanel, colorDivider, transparencyRow, shapePanel, formulationPanel,
            makeDivider(),
            imprintTap, imprintPanel
        ]).then {
            $0.axis = .vertical
            $0.spacing = 10
        }
        card.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(8)
            $0.bottom.equalToSuperview().offset(-12)
            $0.leading.trailing.equalToSuperview().inset(16)
        }
        return card
    }

    // MARK: - Actions

    private func setActions() {
        colorChip.addAction(UIAction { [weak self] _ in self?.togglePanel(.color) }, for: .touchUpInside)
        shapeChip.addAction(UIAction { [weak self] _ in self?.togglePanel(.shape) }, for: .touchUpInside)
        formulationChip.addAction(UIAction { [weak self] _ in self?.togglePanel(.formulation) }, for: .touchUpInside)

        colorPanel.onSelectionChanged = { [weak self] colors in
            self?.viewModel.updateColors(colors); self?.refreshChips()
        }
        transparencyRow.onToggle = { [weak self] on in
            self?.viewModel.setTransparent(on)
        }
        shapePanel.onSelect = { [weak self] shape in
            self?.viewModel.updateShape(shape); self?.refreshChips()
        }
        formulationPanel.onSelect = { [weak self] form in
            self?.viewModel.updateFormulation(form); self?.refreshChips()
        }
        imprintPanel.onChange = { [weak self] front, back in
            self?.viewModel.updateImprint(front: front, back: back)
            self?.imprintSummary.update(front: front, back: back)
        }

        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
    }

    private func togglePanel(_ panel: Panel) {
        openPanel = (openPanel == panel) ? .none : panel
        let colorOpen = openPanel == .color
        colorPanel.isHidden = !colorOpen
        colorDivider.isHidden = !colorOpen
        transparencyRow.isHidden = !colorOpen
        shapePanel.isHidden = openPanel != .shape
        formulationPanel.isHidden = openPanel != .formulation
        imprintPanel.isHidden = openPanel != .imprint
        colorChip.setExpanded(colorOpen)
        shapeChip.setExpanded(openPanel == .shape)
        formulationChip.setExpanded(openPanel == .formulation)
        UIView.animate(withDuration: 0.2) {
            self.imprintChevron.transform = (self.openPanel == .imprint) ? CGAffineTransform(rotationAngle: .pi) : .identity
        }
        // 패널 펼침/접힘으로 섹션0 셀 높이가 바뀌므로 self-sizing 을 다시 측정시킨다.
        collectionView.performBatchUpdates(nil)
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

    private var editingAttributeName: String {
        switch openPanel {
        case .none:        return "none"
        case .color:       return "color"
        case .shape:       return "shape"
        case .formulation: return "formulation"
        case .imprint:     return "imprint"
        }
    }

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

        // 검색 시작 시에만 로딩 셀로 전환. 응답이 오면 candidates 싱크가 결과/빈상태를 그린다.
        output.isSearching
            .receive(on: DispatchQueue.main)
            .sink { [weak self] searching in
                guard let self, searching else { return }
                self.listState = .loading
                self.selectedPillCode = nil
                self.collectionView.reloadSections(IndexSet(integer: Section.candidates.rawValue))
                self.updateFooterVisibility()
            }
            .store(in: &cancelBag)
    }

    // MARK: - Candidates

    private var currentResults: [PillCandidateModel] {
        if case .results(let c) = listState { return c }
        return []
    }

    private func renderCandidates(_ candidates: [PillCandidateModel]) {
        listState = candidates.isEmpty ? .empty : .results(candidates)
        selectedPillCode = nil
        collectionView.reloadSections(IndexSet(integer: Section.candidates.rawValue))
        updateFooterVisibility()
    }

    private func selectCandidate(pillCode: String) {
        selectedPillCode = pillCode
        // 리로드 대신 보이는 후보 셀의 선택 상태만 갱신(썸네일 재로드·깜빡임 방지).
        for case let cell as CandidateCell in collectionView.visibleCells {
            cell.setSelected(cell.pillCode == pillCode)
        }
        hintFooter?.setVisible(false)
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

    // MARK: - Chip Refresh

    private func refreshChips() {
        let colors = viewModel.colors
        let dot = UIView().then {
            $0.backgroundColor = colors.first?.swatchColor ?? DSColor.Neutral._300
            $0.layer.cornerRadius = 7
            $0.layer.borderWidth = 1
            $0.layer.borderColor = DSColor.Neutral._200.cgColor
        }
        dot.snp.makeConstraints { $0.width.height.equalTo(14) }
        // 다중 선택: 1개면 색 이름, 여러 개면 "첫색 외 N".
        let colorValue: String
        if viewModel.isTransparent {
            colorValue = "무색"
        } else if colors.isEmpty {
            colorValue = "선택"
        } else if colors.count == 1 {
            colorValue = colors[0].displayName
        } else {
            colorValue = "\(colors[0].displayName) 외 \(colors.count - 1)"
        }
        colorChip.configure(leading: dot, value: colorValue)

        if let shape = viewModel.shape {
            // 모양 글리프는 bounds 비율이 모양(타원·장방형)을 결정한다 — 가로로 긴 비율이어야
            // 원으로 찌부러지지 않는다. 결과 행(PillResultRowView)과 동일하게 맞춘다.
            let glyph = ShapeGlyphView(shape: shape)
            glyph.snp.makeConstraints { $0.width.equalTo(17); $0.height.equalTo(11) }
            shapeChip.configure(leading: glyph, value: shape.displayName)
        } else {
            shapeChip.configure(leading: nil, value: "선택")
        }

        if let formulation = viewModel.formulation {
            let icon = FormulationIconView(formulation: formulation)
            icon.snp.makeConstraints { $0.width.height.equalTo(16) }
            formulationChip.configure(leading: icon, value: formulation.displayName)
        } else {
            formulationChip.configure(leading: nil, value: "선택")
        }
    }

    // MARK: - Factory

    private func makeRowLabel(_ text: String) -> UILabel {
        UILabel().then {
            $0.text = text
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 14)
            $0.textColor = DSColor.textSecondary
            $0.setContentHuggingPriority(.required, for: .horizontal)
        }
    }

    private func makeDivider() -> UIView { PillEditVC.makeDividerLine() }

    private static func makeDividerLine() -> UIView {
        UIView().then {
            $0.backgroundColor = DSColor.Neutral._200
            $0.snp.makeConstraints { $0.height.equalTo(1) }
        }
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
            case .loading, .empty: return 1
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
            case .results(let candidates):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: CandidateCell.reuseID, for: indexPath
                ) as! CandidateCell
                let candidate = candidates[indexPath.item]
                cell.configure(candidate: candidate, selected: candidate.pillCode == selectedPillCode)
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
            return collectionView.dequeueReusableSupplementaryView(
                ofKind: kind, withReuseIdentifier: CandidateHeaderView.reuseID, for: indexPath
            )
        }
        let footer = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: SelectHintFooter.reuseID, for: indexPath
        ) as! SelectHintFooter
        // 결과가 있고 아직 선택 전일 때만 안내 문구.
        let showHint = !currentResults.isEmpty && selectedPillCode == nil
        footer.setVisible(showHint)
        hintFooter = footer
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
