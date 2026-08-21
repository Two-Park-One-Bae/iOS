import UIKit
import SnapKit
import Then
import DSKit
import Domain

/// ⑤ 인식 결과 세션의 카운트 요약 (완주/이탈 분석용).
struct PillIdentificationSummary {
    let detectedCount: Int
    let confirmedCount: Int
    let unconfirmedCount: Int
    let deletedCount: Int
    let manualAddedCount: Int
    let elapsedSec: Int
}

// ⑤ 인식 결과 — 촬영 사진(bbox 오버레이) + 알약 목록 + 결과 확인 푸터
public final class DrugIdentificationVC: UIViewController {

    // MARK: - Callbacks

    var onSelectPill: ((IdentifiedPill) -> Void)?
    var onAddPill: (() -> Void)?
    var onConfirm: (() -> Void)?
    /// 식별 중단 → 홈 복귀. 뒤로 탭 시 확인 팝업을 거쳐 호출된다.
    var onExitToHome: (() -> Void)?

    // MARK: - Properties

    private let pills: [IdentifiedPill]
    private let capturedImage: UIImage
    private let photoSize: CGFloat = 300

    private var rowViews: [Int: PillResultRowView] = [:]
    /// 사진 위 bbox + 번호 태그 — 삭제 시 같이 걷어내려고 index로 들고 있다.
    private var boxViews: [Int: [UIView]] = [:]
    private var identifiedIndices = Set<Int>()
    private var deletedIndices = Set<Int>()
    private var selectedCandidates: [Int: PillCandidateModel] = [:]
    private var manualPills: [IdentifiedPill] = []
    /// ⑤ 결과 화면 진입 시각 — 완주/이탈까지 경과시간(elapsed_sec) 기준.
    private let appearedAt = Date()

    // MARK: - UI

    private let navBar = DSNavBar(title: "인식 결과").then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let scrollView = UIScrollView().then {
        $0.showsVerticalScrollIndicator = false
        $0.alwaysBounceVertical = true
    }

    private let contentStack = UIStackView().then {
        $0.axis = .vertical
    }

    private let photoCard = PhotoCardView()

    private let listTitle = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 15)
        $0.textColor = DSColor.textPrimary
    }

    private let listStack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 10
        $0.isLayoutMarginsRelativeArrangement = true
        $0.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
    }

    private let footer = UIView().then {
        $0.backgroundColor = DSColor.bgApp
    }

    private let progressLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.medium.font(size: 12)
        $0.textColor = DSColor.textTertiary
        $0.textAlignment = .center
    }

    private let confirmButton = PrimaryButton(title: "결과 확인").then {
        $0.changeCornerRadius(radius: 14)
        $0.setEnabled(false)
    }

    // MARK: - Init

    init(pills: [IdentifiedPill], image: UIImage) {
        self.pills = pills
        self.capturedImage = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        setUI()
        setLayout()
        setContent()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.contentInset.bottom = footer.frame.height
    }

    // MARK: - Setup

    private func setUI() {
        view.backgroundColor = DSColor.bgApp
        photoCard.setImage(capturedImage)
        progressLabel.text = "알약을 모두 식별해주세요 · 0/\(pills.count)"
        // 뒤로가기는 이전 화면이 아니라 '중단하고 홈으로' — 확인 팝업을 먼저 띄운다.
        navBar.onBackTapped = { [weak self] in self?.showExitConfirm() }
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
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

        setupFooter()
    }

    private func setupFooter() {
        let footerStack = UIStackView(arrangedSubviews: [progressLabel, confirmButton]).then {
            $0.axis = .vertical
            $0.spacing = 8
            $0.alignment = .fill
        }
        footer.addSubview(footerStack)
        confirmButton.snp.makeConstraints { $0.height.equalTo(52) }

        footer.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
        }
        footerStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(12)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-28)
        }
    }

    // MARK: - Content

    private func setContent() {
        // Photo Header
        let photoHeader = UIView()
        photoHeader.addSubview(photoCard)
        photoCard.snp.makeConstraints {
            $0.top.equalToSuperview().offset(12)
            $0.bottom.equalToSuperview().offset(-8)
            $0.centerX.equalToSuperview()
        }
        contentStack.addArrangedSubview(photoHeader)
        addBoundingBoxes()

        // Result List
        updateListTitle()
        listStack.addArrangedSubview(listTitle)

        for pill in pills {
            let row = PillResultRowView(pill: pill)
            row.onTap = { [weak self] in self?.onSelectPill?(pill) }
            row.onMenu = { [weak self] in self?.showRowMenu(for: pill, anchor: row) }
            rowViews[pill.index] = row
            listStack.addArrangedSubview(row)
        }

        let addButton = AddPillButton()
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        listStack.addArrangedSubview(addButton)

        contentStack.addArrangedSubview(listStack)

        updateProgress()
    }

    // MARK: - Row Menu (⋮ 수정/삭제)

    private func showRowMenu(for pill: IdentifiedPill, anchor: UIView) {
        let scrim = UIView(frame: view.bounds).then { $0.backgroundColor = .clear }
        addDismissTap(to: scrim)

        let menu = PillActionMenuView()
        menu.onEdit = { [weak self] in
            scrim.removeFromSuperview()
            self?.onSelectPill?(pill)
        }
        menu.onDelete = { [weak self] in
            scrim.removeFromSuperview()
            self?.showDeleteConfirm(pill: pill)
        }
        scrim.addSubview(menu)
        view.addSubview(scrim)

        let anchorFrame = anchor.convert(anchor.bounds, to: scrim)
        menu.snp.makeConstraints {
            $0.trailing.equalTo(scrim.snp.leading).offset(anchorFrame.maxX - 6)
            $0.top.equalTo(scrim.snp.top).offset(anchorFrame.minY + 40)
        }
    }

    private func showDeleteConfirm(pill: IdentifiedPill) {
        let card = ConfirmCardView(
            title: "이 알약을 삭제할까요?",
            cancelTitle: "취소",
            confirmTitle: "삭제",
            isDestructive: true
        )
        presentConfirmCard(card, dismissOnBackgroundTap: true) { [weak self] in
            self?.deletePill(pill)
        }
    }

    /// 뒤로 = 식별 중단. 여기서 나가면 지금까지 확인한 내용이 사라지고,
    /// 이미 차감된 식별 1회도 되돌아오지 않으므로 한 번 확인받는다.
    private func showExitConfirm() {
        presentExitConfirm(
            title: "지금 나가면 식별한 내용이 사라져요",
            message: "식별 횟수도 다시 사용해야 해요"
        ) { [weak self] in
            self?.onExitToHome?()
        }
    }

    // 오버레이 빈 영역 탭으로 닫기 (내부 컨텐츠 터치는 무시)
    private func addDismissTap(to overlay: UIView) {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissOverlay(_:)))
        tap.delegate = self
        overlay.addGestureRecognizer(tap)
    }

    @objc private func dismissOverlay(_ sender: UITapGestureRecognizer) {
        sender.view?.removeFromSuperview()
    }

    private func deletePill(_ pill: IdentifiedPill) {
        rowViews[pill.index]?.removeFromSuperview()
        rowViews[pill.index] = nil
        boxViews[pill.index]?.forEach { $0.removeFromSuperview() }
        boxViews[pill.index] = nil
        deletedIndices.insert(pill.index)
        identifiedIndices.remove(pill.index)
        updateListTitle()
        updateProgress()
    }

    // MARK: - Selection

    func applySelection(pillIndex: Int, candidate: PillCandidateModel) {
        rowViews[pillIndex]?.showSelected(name: candidate.pillName ?? "이름 미상")
        selectedCandidates[pillIndex] = candidate
        identifiedIndices.insert(pillIndex)
        updateProgress()
    }

    // NM-187 수동 추가: 다음 신규 알약 번호
    func nextManualIndex() -> Int {
        let allIndices = Set(pills.map(\.index)).union(manualPills.map(\.index))
        return (allIndices.max() ?? 0) + 1
    }

    // NM-187 수동 추가: 빈 입력으로 선택·확정된 후보를 새 카드로 추가 (추가 버튼 앞에 삽입)
    func addManualPill(index: Int, candidate: PillCandidateModel) {
        let pill = IdentifiedPill(
            index: index,
            thumbnail: nil,
            boundingBox: .zero,
            attribute: PillAttributeModel(
                pillId: "manual-\(index)", colors: [], isTransparent: false,
                shape: nil, formulation: nil, front: nil, back: nil, error: nil
            )
        )
        manualPills.append(pill)
        let row = PillResultRowView(pill: pill)
        row.onTap = { [weak self] in self?.onSelectPill?(pill) }
        row.onMenu = { [weak self] in self?.showRowMenu(for: pill, anchor: row) }
        rowViews[index] = row
        selectedCandidates[index] = candidate
        identifiedIndices.insert(index)
        row.showSelected(name: candidate.pillName ?? "이름 미상")
        let insertAt = max(0, listStack.arrangedSubviews.count - 1)
        listStack.insertArrangedSubview(row, at: insertAt)
        updateProgress()
    }

    // 최종 결과 리스트에 넘길 확정 결과 (삭제 제외 + 선택된 후보 매핑)
    func finalizedResults() -> [(pill: IdentifiedPill, candidate: PillCandidateModel)] {
        let base = pills
            .filter { !deletedIndices.contains($0.index) }
            .compactMap { pill in selectedCandidates[pill.index].map { (pill, $0) } }
        let manual = manualPills
            .filter { !deletedIndices.contains($0.index) }
            .compactMap { pill in selectedCandidates[pill.index].map { (pill, $0) } }
        return base + manual
    }

    /// 완주/이탈 분석용 카운트 요약.
    func identificationSummary() -> PillIdentificationSummary {
        let detected = pills.count
        let deleted = deletedIndices.count
        let manual = manualPills.count
        let confirmed = identifiedIndices.count   // 삭제 반영된 '현재 확정' 수
        let total = detected - deleted + manual
        return PillIdentificationSummary(
            detectedCount: detected,
            confirmedCount: confirmed,
            unconfirmedCount: max(0, total - confirmed),
            deletedCount: deleted,
            manualAddedCount: manual,
            elapsedSec: Int(Date().timeIntervalSince(appearedAt))
        )
    }

    /// 리스트 제목 — 검출된 알약 중 삭제하고 남은 수.
    /// 수동 추가분은 '찾은' 게 아니라서 세지 않는다.
    private func updateListTitle() {
        // 수동 추가분도 같은 deletedIndices에 들어오므로 뺄셈이 아니라 실제로 남은 걸 센다.
        let remaining = pills.filter { !deletedIndices.contains($0.index) }.count
        listTitle.text = remaining > 0
            ? "알약 \(remaining)개를 찾았어요"
            : "찾은 알약을 모두 지웠어요"
    }

    private func updateProgress() {
        let total = pills.count - deletedIndices.count + manualPills.count
        let done = identifiedIndices.count

        if done == total {
            progressLabel.text = "모든 알약을 식별했어요"
            progressLabel.textColor = DSColor.Primary._500
            confirmButton.setEnabled(true)
        } else {
            progressLabel.text = "알약을 모두 식별해주세요 · \(done)/\(total)"
            progressLabel.textColor = DSColor.textTertiary
            confirmButton.setEnabled(false)
        }
    }

    // 사진 위 bbox + 번호 태그
    private func addBoundingBoxes() {
        photoCard.layoutIfNeeded()
        let container = photoCard.photoContainer

        for pill in pills {
            let box = pill.boundingBox
            let rect = CGRect(
                x: box.minX * photoSize,
                y: box.minY * photoSize,
                width: box.width * photoSize,
                height: box.height * photoSize
            )

            let boxView = UIView(frame: rect).then {
                $0.backgroundColor = .clear
                $0.layer.borderColor = DSColor.Primary._500.cgColor
                $0.layer.borderWidth = 2
                $0.layer.cornerRadius = 4
            }
            container.addSubview(boxView)

            let tag = UIView().then {
                $0.backgroundColor = DSColor.Primary._500
                $0.layer.cornerRadius = 4
                $0.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner]
            }
            let tagLabel = UILabel().then {
                $0.text = "\(pill.index)"
                $0.font = DSKitFontFamily.Pretendard.bold.font(size: 11)
                $0.textColor = DSColor.Neutral._0
                $0.textAlignment = .center
            }
            tag.addSubview(tagLabel)
            container.addSubview(tag)

            tagLabel.translatesAutoresizingMaskIntoConstraints = false
            tag.translatesAutoresizingMaskIntoConstraints = false
            let tagX = max(0, rect.minX)
            let tagY = max(0, rect.minY - 18)
            NSLayoutConstraint.activate([
                tagLabel.topAnchor.constraint(equalTo: tag.topAnchor, constant: 1),
                tagLabel.bottomAnchor.constraint(equalTo: tag.bottomAnchor, constant: -1),
                tagLabel.leadingAnchor.constraint(equalTo: tag.leadingAnchor, constant: 6),
                tagLabel.trailingAnchor.constraint(equalTo: tag.trailingAnchor, constant: -6),
                tag.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: tagX),
                tag.topAnchor.constraint(equalTo: container.topAnchor, constant: tagY)
            ])

            boxViews[pill.index] = [boxView, tag]
        }
    }

    // MARK: - Actions

    @objc private func confirmTapped() {
        onConfirm?()
    }

    @objc private func addTapped() {
        onAddPill?()
    }
}

// MARK: - Overlay 빈 영역 탭 감지

extension DrugIdentificationVC: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 오버레이(scrim/dim) 자체를 탭했을 때만 닫기 — 메뉴/카드 내부 터치는 통과
        touch.view === gestureRecognizer.view
    }
}
