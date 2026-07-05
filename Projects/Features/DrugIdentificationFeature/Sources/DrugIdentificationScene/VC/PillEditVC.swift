import UIKit
import Combine
import SnapKit
import Then
import DSKit
import Domain

// ⑧ 알약 수정 — 속성 편집(색상/모양/제형/각인 인라인 펼침) + 실시간 후보 + 선택/확인
final class PillEditVC: UIViewController {

    // MARK: - Callbacks

    var onConfirm: ((PillCandidateModel) -> Void)?
    var onCancel: (() -> Void)?
    var onBackTapped: (() -> Void)?

    // MARK: - Properties

    private let viewModel: PillEditViewModel
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private var cancelBag = Set<AnyCancellable>()

    private var candidateRows: [CandidateRowView] = []
    private var selectedCandidate: PillCandidateModel?

    private enum Panel { case none, color, shape, formulation, imprint }
    private var openPanel: Panel = .none

    // MARK: - UI

    private lazy var navBar = DSNavBar(title: "알약 \(viewModel.pillIndex) 수정").then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }
    private let scrollView = UIScrollView().then {
        $0.showsVerticalScrollIndicator = false
        $0.keyboardDismissMode = .interactive
    }
    private let contentStack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 14
        $0.isLayoutMarginsRelativeArrangement = true
        $0.layoutMargins = UIEdgeInsets(top: 12, left: 20, bottom: 24, right: 20)
    }

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

    private let candidatesStack = UIStackView().then { $0.axis = .vertical; $0.spacing = 8 }
    private let selectHint = UILabel().then {
        $0.text = "후보를 선택하면 확인 버튼이 나타나요"
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
        $0.textColor = DSColor.textTertiary
        $0.textAlignment = .center
    }
    private let emptyView = PillEditVC.makeEmptyView()

    private let footer = UIView().then {
        $0.backgroundColor = DSColor.bgApp
        $0.layer.shadowColor = DSColor.textPrimary.cgColor
        $0.layer.shadowOpacity = 0.1
        $0.layer.shadowOffset = CGSize(width: 0, height: -4)
        $0.layer.shadowRadius = 16
    }
    private let cancelButton = SecondaryButton(title: "취소")
    private let confirmButton = PrimaryButton(title: "확인")

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
        navBar.onBackTapped = { [weak self] in self?.onBackTapped?() }
        refreshChips()
        colorPanel.setSelected(viewModel.colors.first)
        shapePanel.setSelected(viewModel.shape)
        formulationPanel.setSelected(viewModel.formulation)
        transparencyRow.setOn(viewModel.isTransparent)
        imprintSummary.update(front: viewModel.front, back: viewModel.back)
        [colorPanel, colorDivider, transparencyRow, shapePanel, formulationPanel, imprintPanel, emptyView].forEach { $0.isHidden = true }
        footer.isHidden = true
    }

    private func setLayout() {
        view.addSubview(navBar)
        view.addSubview(scrollView)
        view.addSubview(footer)
        scrollView.addSubview(contentStack)

        navBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
        }
        scrollView.snp.makeConstraints {
            $0.top.equalTo(navBar.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        contentStack.snp.makeConstraints {
            $0.edges.equalTo(scrollView.contentLayoutGuide)
            $0.width.equalTo(scrollView.frameLayoutGuide)
        }

        contentStack.addArrangedSubview(makeAttributeCard())
        contentStack.addArrangedSubview(makeCandidateHeader())
        contentStack.addArrangedSubview(candidatesStack)
        contentStack.addArrangedSubview(selectHint)
        contentStack.addArrangedSubview(emptyView)

        setupFooter()
    }

    private func setupFooter() {
        let stack = UIStackView(arrangedSubviews: [cancelButton, confirmButton]).then {
            $0.axis = .horizontal
            $0.spacing = 10
            $0.distribution = .fillEqually
        }
        footer.addSubview(stack)
        footer.snp.makeConstraints { $0.leading.trailing.bottom.equalToSuperview() }
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(12)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-28)
        }
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

    private func makeCandidateHeader() -> UIView {
        let title = UILabel().then {
            $0.text = "후보"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 15)
            $0.textColor = DSColor.textPrimary
        }
        let zap = UIImageView().then {
            $0.image = UIImage(systemName: "bolt.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
            $0.tintColor = DSColor.Primary._500
            $0.contentMode = .scaleAspectFit
        }
        let hint = UILabel().then {
            $0.text = "실시간"
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 12)
            $0.textColor = DSColor.Primary._600
        }
        let hintStack = UIStackView(arrangedSubviews: [zap, hint]).then {
            $0.axis = .horizontal; $0.spacing = 4; $0.alignment = .center
        }
        return UIStackView(arrangedSubviews: [title, UIView(), hintStack]).then {
            $0.axis = .horizontal; $0.alignment = .center
        }
    }

    // MARK: - Actions

    private func setActions() {
        colorChip.addAction(UIAction { [weak self] _ in self?.togglePanel(.color) }, for: .touchUpInside)
        shapeChip.addAction(UIAction { [weak self] _ in self?.togglePanel(.shape) }, for: .touchUpInside)
        formulationChip.addAction(UIAction { [weak self] _ in self?.togglePanel(.formulation) }, for: .touchUpInside)

        colorPanel.onSelect = { [weak self] color in
            self?.viewModel.updateColors([color]); self?.refreshChips()
        }
        transparencyRow.onToggle = { [weak self] on in self?.viewModel.setTransparent(on) }
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
    }

    @objc private func cancelTapped() { onCancel?() }
    @objc private func confirmTapped() {
        guard let selected = selectedCandidate else { return }
        onConfirm?(selected)
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
        output.isEmpty
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEmpty in
                self?.emptyView.isHidden = !isEmpty
                self?.candidatesStack.isHidden = isEmpty
            }
            .store(in: &cancelBag)
    }

    private func renderCandidates(_ candidates: [PillCandidateModel]) {
        candidateRows.forEach { $0.removeFromSuperview() }
        candidateRows.removeAll()
        selectedCandidate = nil
        updateFooterVisibility()

        for candidate in candidates {
            let row = CandidateRowView(candidate: candidate)
            row.onTap = { [weak self] in self?.selectCandidate(row) }
            candidatesStack.addArrangedSubview(row)
            candidateRows.append(row)
        }
        selectHint.isHidden = candidates.isEmpty
    }

    private func selectCandidate(_ row: CandidateRowView) {
        selectedCandidate = row.candidate
        candidateRows.forEach { $0.setSelected($0 === row) }
        updateFooterVisibility()
    }

    private func updateFooterVisibility() {
        let hasSelection = selectedCandidate != nil
        footer.isHidden = !hasSelection
        selectHint.isHidden = hasSelection || candidateRows.isEmpty
        scrollView.contentInset.bottom = hasSelection ? footer.frame.height : 0
    }

    // MARK: - Chip Refresh

    private func refreshChips() {
        let color = viewModel.colors.first
        let dot = UIView().then {
            $0.backgroundColor = color?.swatchColor ?? DSColor.Neutral._300
            $0.layer.cornerRadius = 7
            $0.layer.borderWidth = 1
            $0.layer.borderColor = DSColor.Neutral._200.cgColor
        }
        dot.snp.makeConstraints { $0.width.height.equalTo(14) }
        colorChip.configure(leading: dot, value: viewModel.isTransparent ? "무색" : (color?.displayName ?? "선택"))

        if let shape = viewModel.shape {
            let glyph = ShapeGlyphView(shape: shape)
            glyph.snp.makeConstraints { $0.width.height.equalTo(14) }
            shapeChip.configure(leading: glyph, value: shape.displayName)
        } else {
            shapeChip.configure(leading: nil, value: "선택")
        }

        if let formulation = viewModel.formulation {
            let icon = FormulationIconView(formulation: formulation)
            icon.snp.makeConstraints { $0.width.equalTo(16); $0.height.equalTo(14) }
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

    private static func makeEmptyView() -> UIView {
        let container = UIView()
        let circle = UIView().then {
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = 32
        }
        circle.snp.makeConstraints { $0.width.height.equalTo(64) }
        let icon = UIImageView().then {
            $0.image = UIImage(systemName: "magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .regular))
            $0.tintColor = DSColor.textTertiary
            $0.contentMode = .scaleAspectFit
        }
        circle.addSubview(icon)
        icon.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(30) }

        let title = UILabel().then {
            $0.text = "조건에 맞는 후보가 없어요"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 16)
            $0.textColor = DSColor.textPrimary
            $0.textAlignment = .center
        }
        let desc = UILabel().then {
            $0.text = "색·모양·제형·각인 중 하나를 완화하면\n후보가 다시 나타나요"
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
            $0.textColor = DSColor.textTertiary
            $0.textAlignment = .center
            $0.numberOfLines = 0
        }
        let texts = UIStackView(arrangedSubviews: [title, desc]).then {
            $0.axis = .vertical; $0.spacing = 6; $0.alignment = .center
        }
        let stack = UIStackView(arrangedSubviews: [circle, texts]).then {
            $0.axis = .vertical; $0.spacing = 14; $0.alignment = .center
        }
        container.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(40)
            $0.leading.trailing.equalToSuperview()
        }
        return container
    }
}
