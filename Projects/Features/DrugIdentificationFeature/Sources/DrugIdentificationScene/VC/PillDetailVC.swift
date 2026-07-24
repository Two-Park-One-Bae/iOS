import UIKit
import Combine
import SnapKit
import Then
import DSKit
import Domain
import Kingfisher

// ⑩ 세부정보 — pillCode로 성분·성상·허가문서(효능효과/용법용량/주의사항)를 조회해 렌더.
final class PillDetailVC: UIViewController {

    // MARK: - Callbacks

    var onBackTapped: (() -> Void)?

    // MARK: - Dependencies

    private let viewModel: PillDetailViewModel

    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private let retrySubject = PassthroughSubject<Void, Never>()
    private var cancelBag = Set<AnyCancellable>()

    // 로드된 상세 + 현재 선택 탭
    private var detail: PillDetailModel?
    private var selectedDocIndex = 0

    // MARK: - UI

    private lazy var navBar = DSNavBar(title: "세부정보").then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let containerView = UIView()   // 상태별 컨텐츠 교체

    // MARK: - Init

    init(viewModel: PillDetailViewModel) {
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
        viewDidLoadSubject.send(())
    }

    private func setLayout() {
        view.addSubview(navBar)
        navBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
        }
        navBar.onBackTapped = { [weak self] in self?.onBackTapped?() }

        view.addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.top.equalTo(navBar.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func bind() {
        let output = viewModel.transform(input: .init(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            retry: retrySubject.eraseToAnyPublisher()
        ))
        output.state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.render(state) }
            .store(in: &cancelBag)
    }

    // MARK: - State Render

    private func render(_ state: PillDetailViewModel.State) {
        containerView.subviews.forEach { $0.removeFromSuperview() }
        switch state {
        case .loading:
            containerView.addSubview(makeLoadingView())
        case .loaded(let model):
            self.detail = model
            self.selectedDocIndex = 0
            containerView.addSubview(makeContentScroll(model))
        case .notFound:
            containerView.addSubview(makeMessageView(
                icon: .fileSearch,
                title: "세부정보가 없어요",
                message: "이 약은 아직 등록된 세부정보가 없습니다.",
                retry: false
            ))
        case .failure(let message):
            containerView.addSubview(makeMessageView(
                icon: .alertTriangle,
                title: "세부정보를 불러오지 못했어요",
                message: message,
                retry: true
            ))
        case .revoked:
            containerView.addSubview(makeRevokedView())
        }
        containerView.subviews.last?.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    // MARK: - Loading / Message states

    private func makeLoadingView() -> UIView {
        let container = UIView()
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = DSColor.Primary._500
        spinner.startAnimating()
        let label = UILabel()
        label.text = "세부정보를 불러오는 중…"
        label.font = DSKitFontFamily.Pretendard.regular.font(size: 14)
        label.textColor = DSColor.textSecondary
        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .center
        container.addSubview(stack)
        stack.snp.makeConstraints { $0.center.equalToSuperview() }
        return container
    }

    private func makeMessageView(icon: DSIcon, title: String, message: String, retry: Bool) -> UIView {
        let container = UIView()

        let iconView = UIImageView(image: icon.uiImage)
        iconView.tintColor = DSColor.Neutral._400
        iconView.contentMode = .scaleAspectFit
        iconView.snp.makeConstraints { $0.width.height.equalTo(44) }

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DSKitFontFamily.Pretendard.bold.font(size: 18)
        titleLabel.textColor = DSColor.textPrimary
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = DSKitFontFamily.Pretendard.regular.font(size: 14)
        messageLabel.textColor = DSColor.textSecondary
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, messageLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.setCustomSpacing(20, after: iconView)
        container.addSubview(stack)
        stack.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(40)
        }

        if retry {
            let button = PrimaryButton(title: "다시 시도")
            button.addAction(UIAction { [weak self] _ in self?.retrySubject.send(()) }, for: .touchUpInside)
            container.addSubview(button)
            button.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(24)
                $0.bottom.equalTo(container.safeAreaLayoutGuide).inset(24)
            }
        }
        return container
    }

    // ⑩-g 허가 종료 안내 — REVOKED 품목은 조회 없이 안내만 표시 (NM-342, 디자인 UwBjQ).
    // 96 원형(warning-50) + file-x(warning-600 42pt) + 타이틀 20 + 설명 15(lineHeight 1.5) + '뒤로'.
    private func makeRevokedView() -> UIView {
        let container = UIView()

        let iconBg = UIView()
        iconBg.backgroundColor = DSColor.Warning._50
        iconBg.layer.cornerRadius = 48
        iconBg.snp.makeConstraints { $0.width.height.equalTo(96) }

        // 디자인 아이콘 lucide file-x (ClL1Q).
        let iconView = UIImageView(image: DSIcon.fileX.uiImage)
        iconView.tintColor = DSColor.Warning._600
        iconView.contentMode = .scaleAspectFit
        iconBg.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.height.equalTo(42)
        }

        let titleLabel = UILabel()
        titleLabel.text = "허가가 종료된 약이에요"
        titleLabel.font = DSKitFontFamily.Pretendard.bold.font(size: 20)
        titleLabel.textColor = DSColor.textPrimary
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.5
        style.alignment = .center
        messageLabel.attributedText = NSAttributedString(
            string: "허가가 취소되거나 취하된 품목이라\n세부정보가 제공되지 않아요\n후보 선택과 식별 결과에는 영향이 없어요",
            attributes: [
                .paragraphStyle: style,
                .font: DSKitFontFamily.Pretendard.regular.font(size: 15),
                .foregroundColor: DSColor.textSecondary
            ]
        )
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center

        let texts = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        texts.axis = .vertical
        texts.spacing = 8
        texts.alignment = .center

        let stack = UIStackView(arrangedSubviews: [iconBg, texts])
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .center
        container.addSubview(stack)
        stack.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(40)
        }

        let backButton = SecondaryButton(title: "뒤로")
        backButton.addAction(UIAction { [weak self] _ in self?.onBackTapped?() }, for: .touchUpInside)
        container.addSubview(backButton)
        backButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalTo(container.safeAreaLayoutGuide).inset(28)
        }
        return container
    }

    // MARK: - Loaded content

    private func makeContentScroll(_ model: PillDetailModel) -> UIView {
        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        scroll.alwaysBounceVertical = true

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        scroll.addSubview(stack)
        stack.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalToSuperview()
        }

        stack.addArrangedSubview(makeSummaryHeader(model))
        if !model.documents.isEmpty {
            stack.addArrangedSubview(makeDocTabs(model))
            let body = docBodyContainer
            stack.addArrangedSubview(body)
            rebuildDocBody(model)
        }
        stack.addArrangedSubview(makeProductInfo(model))
        stack.addArrangedSubview(makeSource())
        return scroll
    }

    // 요약 헤더: 분류칩 · 품목명 · 업체 · 이미지 · 성상 · 성분
    private func makeSummaryHeader(_ model: PillDetailModel) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8
        container.backgroundColor = DSColor.surface
        container.isLayoutMarginsRelativeArrangement = true
        container.layoutMargins = UIEdgeInsets(top: 14, left: 20, bottom: 16, right: 20)

        let chip = DSChip(text: model.classification.displayName, showDot: false)
        let chipRow = UIStackView(arrangedSubviews: [chip, UIView()])
        chipRow.axis = .horizontal

        let name = UILabel()
        name.text = model.name
        name.font = DSKitFontFamily.Pretendard.bold.font(size: 20)
        name.textColor = DSColor.textPrimary
        name.numberOfLines = 0

        let company = UILabel()
        company.text = model.companyName
        company.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
        company.textColor = DSColor.textSecondary

        container.addArrangedSubview(chipRow)
        container.addArrangedSubview(name)
        container.addArrangedSubview(company)

        if let imageUrlString = model.pillImageUrl, let url = URL(string: imageUrlString) {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.backgroundColor = DSColor.Neutral._100
            imageView.layer.cornerRadius = 12
            imageView.clipsToBounds = true
            container.setCustomSpacing(12, after: company)
            container.addArrangedSubview(imageView)
            // 낱알 원본은 가로형(식약처 표준 ≈ 1.83:1). 틀을 이미지 실제 비율에 맞춰 좌우 여백·왜곡을 없앤다.
            // 로드 전엔 표준 비율로 박스를 잡고, 완료 시 실제 비율로 교체. 회색 박스+페이드,
            // 로드 실패(이미지 없는 품목=CDN 404) 시 회색 박스가 폴백 플레이스홀더로 남는다.
            imageView.snp.makeConstraints { $0.height.equalTo(imageView.snp.width).multipliedBy(426.0 / 780.0) }
            imageView.kf.setImage(with: url, options: [.transition(.fade(0.25))]) { [weak imageView] result in
                guard let imageView, case .success(let value) = result, value.image.size.width > 0 else { return }
                let ratio = value.image.size.height / value.image.size.width
                imageView.snp.remakeConstraints { $0.height.equalTo(imageView.snp.width).multipliedBy(ratio) }
            }
        }

        if let appearance = model.appearance, !appearance.isEmpty {
            container.setCustomSpacing(12, after: container.arrangedSubviews.last ?? company)
            container.addArrangedSubview(makeInfoLine(label: "성상", value: appearance))
        }
        let ingredientText = model.ingredients
            .map { "\($0.name) \($0.amount)\($0.unit)" }
            .joined(separator: ", ")
        if !ingredientText.isEmpty {
            container.addArrangedSubview(makeInfoLine(label: "성분", value: ingredientText))
        }
        return container
    }

    // 문서 탭 (효능효과 | 용법용량 | 사용상 주의사항)
    private lazy var docBodyContainer = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 12
        $0.isLayoutMarginsRelativeArrangement = true
        $0.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 4, right: 20)
    }
    private var tabButtons: [UIButton] = []

    private func makeDocTabs(_ model: PillDetailModel) -> UIView {
        tabButtons = []
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 4
        row.distribution = .fillEqually
        row.backgroundColor = DSColor.surface
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)

        for (index, doc) in model.documents.enumerated() {
            let button = makeTabButton(title: doc.type.displayName, index: index)
            tabButtons.append(button)
            row.addArrangedSubview(button)
        }
        let border = UIView()
        border.backgroundColor = DSColor.border
        row.addSubview(border)
        border.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }
        updateTabSelection()
        return row
    }

    private func makeTabButton(title: String, index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = DSKitFontFamily.Pretendard.semiBold.font(size: 14)
        button.titleLabel?.numberOfLines = 1
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 4, bottom: 14, right: 4)

        let underline = UIView()
        underline.backgroundColor = DSColor.Primary._500
        underline.tag = 99
        underline.isHidden = true
        button.addSubview(underline)
        underline.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(2)
        }
        button.addAction(UIAction { [weak self] _ in self?.selectDoc(index) }, for: .touchUpInside)
        return button
    }

    private func selectDoc(_ index: Int) {
        guard index != selectedDocIndex, let model = detail else { return }
        selectedDocIndex = index
        updateTabSelection()
        rebuildDocBody(model)
    }

    private func updateTabSelection() {
        for (index, button) in tabButtons.enumerated() {
            let selected = index == selectedDocIndex
            button.setTitleColor(selected ? DSColor.Primary._600 : DSColor.textTertiary, for: .normal)
            button.viewWithTag(99)?.isHidden = !selected
        }
    }

    // 선택 문서의 블록을 본문에 렌더 (주의사항=아코디언, 그 외=평면)
    private func rebuildDocBody(_ model: PillDetailModel) {
        docBodyContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard model.documents.indices.contains(selectedDocIndex) else { return }
        let doc = model.documents[selectedDocIndex]

        if doc.type == .caution {
            makeAccordionSections(from: doc.blocks).forEach { docBodyContainer.addArrangedSubview($0) }
        } else {
            doc.blocks.forEach { docBodyContainer.addArrangedSubview(renderBlock($0)) }
        }
    }

    private func renderBlock(_ block: BlockModel) -> UIView {
        switch block {
        case .heading(let spans):    return PillDetailRenderer.headingLabel(spans)
        case .paragraph(let spans):  return PillDetailRenderer.paragraphLabel(spans)
        case .table(let caption, let rows): return PillDetailTableView(rows: rows, caption: caption)
        case .image(let src):        return PillDetailRenderer.imageView(src: src)
        }
    }

    // HEADING을 접기 단위로 아코디언 섹션 구성. 첫 HEADING 이전 블록은 그대로 렌더.
    private func makeAccordionSections(from blocks: [BlockModel]) -> [UIView] {
        var views: [UIView] = []
        var currentTitle: [SpanModel]?
        var currentContent: [UIView] = []
        var isFirst = true

        func flush() {
            if let title = currentTitle {
                views.append(PillDetailAccordionSection(title: title, contentViews: currentContent, expanded: isFirst))
                isFirst = false
            }
            currentTitle = nil
            currentContent = []
        }

        for block in blocks {
            if case .heading(let spans) = block {
                flush()
                currentTitle = spans
            } else if currentTitle != nil {
                currentContent.append(renderBlock(block))
            } else {
                views.append(renderBlock(block))   // 첫 헤딩 이전 블록
            }
        }
        flush()
        return views
    }

    // 제품정보 (저장방법/유효기간/포장단위)
    private func makeProductInfo(_ model: PillDetailModel) -> UIView {
        let rows: [(String, String?)] = [
            ("저장방법", model.storageMethod),
            ("유효기간", model.validTerm),
            ("포장단위", model.packUnit),
        ].filter { $0.1?.isEmpty == false }
        guard !rows.isEmpty else { return UIView() }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 20, bottom: 0, right: 20)

        let heading = UILabel()
        heading.text = "제품정보"
        heading.font = DSKitFontFamily.Pretendard.bold.font(size: 16)
        heading.textColor = DSColor.textPrimary
        stack.addArrangedSubview(heading)

        for (label, value) in rows {
            stack.addArrangedSubview(makeInfoLine(label: label, value: value ?? ""))
        }
        return stack
    }

    private func makeSource() -> UIView {
        let label = UILabel()
        label.text = "출처: 식품의약품안전처 의약품 제품 허가정보. 실제 복약은 반드시 의사·약사와 상의하세요."
        label.font = DSKitFontFamily.Pretendard.regular.font(size: 11)
        label.textColor = DSColor.textTertiary
        label.numberOfLines = 0

        let container = UIView()
        container.addSubview(label)
        label.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 16, left: 20, bottom: 24, right: 20))
        }
        return container
    }

    // "라벨  값" 한 줄
    private func makeInfoLine(label: String, value: String) -> UIView {
        let key = UILabel()
        key.text = label
        key.font = DSKitFontFamily.Pretendard.semiBold.font(size: 13)
        key.textColor = DSColor.textTertiary
        key.setContentHuggingPriority(.required, for: .horizontal)
        key.snp.makeConstraints { $0.width.equalTo(52) }

        let val = UILabel()
        val.text = value
        val.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
        val.textColor = DSColor.textSecondary
        val.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [key, val])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .top
        return row
    }
}

// MARK: - Display names

private extension PillClassificationModel {
    var displayName: String {
        switch self {
        case .etc:     return "전문의약품"
        case .otc:     return "일반의약품"
        case .unknown: return "의약품"
        }
    }
}

private extension LicenseDocTypeModel {
    var displayName: String {
        switch self {
        case .effect:  return "효능효과"
        case .dosage:  return "용법용량"
        case .caution: return "사용상 주의사항"
        case .unknown: return "기타"
        }
    }
}
