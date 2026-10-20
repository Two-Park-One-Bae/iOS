import UIKit
import SnapKit
import Then
import DSKit
import Domain
import Core

/// ⑤ 인식 결과 세션의 카운트 요약 (완주/이탈 분석용).
struct PillIdentificationSummary {
    let detectedCount: Int
    let confirmedCount: Int
    let unconfirmedCount: Int
    let deletedCount: Int
    let manualAddedCount: Int
    let elapsedSec: Int
}

// ⑤ 식별 결과 (V2.1.0 NM-587) — 촬영 사진(bbox 오버레이) + 진행 + 알약 목록 + 하단 바(공유 · 완료).
// 결과를 확인하는 화면을 따로 두지 않는다 — 이 화면이 최종 결과를 겸한다.
public final class DrugIdentificationVC: UIViewController {

    // MARK: - Callbacks

    var onSelectPill: ((IdentifiedPill) -> Void)?
    var onAddPill: (() -> Void)?
    /// `완료`(미확정이 남았으면 종료 확인 뒤) — 받는 쪽이 기록을 저장한다.
    var onComplete: (() -> Void)?
    /// 식별 완료 카드의 ⓘ → 세부정보
    var onSelectDetail: ((String, LicenseStatus) -> Void)?
    /// 식별 중단 → 홈 복귀. 뒤로 탭 시 확인 팝업을 거쳐 호출된다.
    var onExitToHome: (() -> Void)?

    // MARK: - Properties

    private let pills: [IdentifiedPill]
    private let capturedImage: UIImage
    private let photoSize: CGFloat = 300

    private var rowViews: [Int: PillResultRowView] = [:]
    /// 사진 위 bbox + 번호 태그 — 삭제 시 같이 걷어내고, 상태·번호가 바뀌면 다시 칠하려고 index로 들고 있다.
    private var boxViews: [Int: (box: UIView, tag: UIView, label: UILabel)] = [:]
    /// 화면에 보이는 순서(검출 순 → 수동 추가 순). 번호는 이 순서의 1-based 위치 — 삭제하면 다시 매긴다.
    private var displayOrder: [Int] = []
    /// 알약별 수정 조건 — 수정 화면을 닫았다 열어도 고친 값이 이어진다(한 식별 흐름 안에서만).
    private var conditionsByIndex: [Int: PillConditions] = [:]
    private var editRecordsByIndex: [Int: PillEditRecord] = [:]
    private var identifiedIndices = Set<Int>()
    private var deletedIndices = Set<Int>()
    private var selectedCandidates: [Int: PillCandidateModel] = [:]
    private var manualPills: [IdentifiedPill] = []
    /// ⑤ 결과 화면 진입 시각 — 완주/이탈까지 경과시간(elapsed_sec) 기준.
    private let appearedAt = Date()

    // MARK: - UI

    private let navBar = DSNavBar(title: "식별 결과").then {
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

    // 진행 — `2 / 3 식별 완료` · `1개 남음` + 막대(초록)
    private let progressDoneLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 13)
        $0.textColor = DSColor.textPrimary
    }

    private let progressLeftLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
        $0.textColor = DSColor.textTertiary
    }

    private let progressBar = ResultProgressBar()

    private let shareButton = SecondaryButton(title: "공유").setEnabled(false)
    private let completeButton = PrimaryButton(title: "완료").setEnabled(false)
    private lazy var bottomBar = DSBottomBar(
        buttons: [shareButton, completeButton],
        disclaimer: PillDisclaimer.notice
    ).then {
        $0.backgroundColor = DSColor.surface
    }

    // MARK: - Init

    init(pills: [IdentifiedPill], image: UIImage) {
        self.pills = pills
        self.capturedImage = image
        self.displayOrder = pills.map(\.index)
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
        scrollView.contentInset.bottom = bottomBar.frame.height
    }

    // MARK: - Setup

    private func setUI() {
        view.backgroundColor = DSColor.surface
        photoCard.setImage(capturedImage)
        // 뒤로가기는 이전 화면이 아니라 '중단하고 들어온 화면으로' — 확인 팝업을 먼저 띄운다.
        navBar.onBackTapped = { [weak self] in self?.showExitConfirm() }
        completeButton.addTarget(self, action: #selector(completeTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
    }

    private func setLayout() {
        view.addSubview(navBar)
        view.addSubview(scrollView)
        view.addSubview(bottomBar)
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

    /// 하단 바는 판 없이 탭 바 위에 띄운다(디자인 `IkyB0`) — 목록은 그 뒤로 스크롤된다.
    private func setupFooter() {
        bottomBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide)
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

        // Result List — 제목 · 진행
        updateListTitle()
        let progressText = UIStackView(arrangedSubviews: [progressDoneLabel, UIView(), progressLeftLabel]).then {
            $0.axis = .horizontal
            $0.alignment = .lastBaseline
        }
        let head = UIStackView(arrangedSubviews: [listTitle, progressText, progressBar]).then {
            $0.axis = .vertical
            $0.spacing = 6
        }
        listStack.addArrangedSubview(head)

        for pill in pills {
            let row = makeRow(for: pill)
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
            message: "사용한 식별 횟수는 돌아오지 않아요"
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

    /// 카드와 사진 위 영역을 함께 지우고 번호를 다시 매긴다(spec ⋮ 삭제). 수동 추가 알약은 영역이 없어 목록에서만 뺀다.
    private func deletePill(_ pill: IdentifiedPill) {
        rowViews[pill.index]?.removeFromSuperview()
        rowViews[pill.index] = nil
        if let views = boxViews[pill.index] {
            views.box.removeFromSuperview()
            views.tag.removeFromSuperview()
        }
        boxViews[pill.index] = nil
        displayOrder.removeAll { $0 == pill.index }
        deletedIndices.insert(pill.index)
        identifiedIndices.remove(pill.index)
        refreshAll()
        updateListTitle()
        updateProgress()
    }

    // MARK: - State · 번호

    private func makeRow(for pill: IdentifiedPill) -> PillResultRowView {
        let row = PillResultRowView(number: number(of: pill.index), thumbnail: pill.thumbnail, state: state(of: pill))
        row.onTap = { [weak self] in self?.onSelectPill?(pill) }
        row.onMenu = { [weak self] in self?.showRowMenu(for: pill, anchor: row) }
        row.onInfo = { [weak self] in
            guard let self, let candidate = self.selectedCandidates[pill.index] else { return }
            self.onSelectDetail?(candidate.pillCode, candidate.licenseStatus)
        }
        rowViews[pill.index] = row
        return row
    }

    private func number(of index: Int) -> Int {
        (displayOrder.firstIndex(of: index) ?? 0) + 1
    }

    // MARK: - 수정 화면과 주고받기

    func displayNumber(of index: Int) -> Int { number(of: index) }

    /// 수동 추가로 새로 생길 카드의 번호.
    func nextDisplayNumber() -> Int { displayOrder.count + 1 }

    func isManual(_ index: Int) -> Bool { manualPills.contains { $0.index == index } }

    func conditions(of pill: IdentifiedPill) -> PillConditions {
        conditionsByIndex[pill.index] ?? PillConditions(model: pill.modelOutput)
    }

    func store(_ conditions: PillConditions, for index: Int) {
        conditionsByIndex[index] = conditions
    }

    /// 조건과 짝 — 조건을 이어서 여는 이상 수정 횟수도 이어서 센다(NM-535).
    func editRecord(of index: Int) -> PillEditRecord {
        editRecordsByIndex[index] ?? PillEditRecord()
    }

    func store(_ record: PillEditRecord, for index: Int) {
        editRecordsByIndex[index] = record
    }

    /// 식별 완료가 가장 우선 — 인식 실패 알약도 직접 입력해 고르면 식별 완료다.
    private func state(of pill: IdentifiedPill) -> PillResultState {
        if let candidate = selectedCandidates[pill.index] {
            return .identified(
                name: candidate.pillName ?? "이름 미상",
                company: candidate.companyName,
                isRevoked: candidate.licenseStatus == .revoked,
                isManual: manualPills.contains { $0.index == pill.index }
            )
        }
        return pill.isExtractionFailed ? .failed : .pending
    }

    /// 카드 · 사진 위 영역의 번호와 색을 현재 상태로 다시 칠한다.
    private func refreshAll() {
        for pill in pills + manualPills where !deletedIndices.contains(pill.index) {
            let state = state(of: pill)
            let number = number(of: pill.index)
            rowViews[pill.index]?.configure(number: number, state: state)
            if let views = boxViews[pill.index] {
                views.box.layer.borderColor = state.tone.accent.cgColor
                views.tag.backgroundColor = state.tone.accent
                views.label.text = "\(number)"
            }
        }
    }

    // MARK: - Selection

    func applySelection(pillIndex: Int, candidate: PillCandidateModel) {
        selectedCandidates[pillIndex] = candidate
        identifiedIndices.insert(pillIndex)
        refreshAll()
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
            pillId: "manual-\(index)",
            thumbnail: nil,
            boundingBox: .zero,
            attribute: nil
        )
        manualPills.append(pill)
        displayOrder.append(index)
        selectedCandidates[index] = candidate
        identifiedIndices.insert(index)
        let row = makeRow(for: pill)
        row.setThumbnail(url: candidate.pillThumbnailUrl)
        let insertAt = max(0, listStack.arrangedSubviews.count - 1)
        listStack.insertArrangedSubview(row, at: insertAt)
        updateProgress()
    }

    /// 기록 · 공유에 넣을 확정 결과 — 화면 순서 그대로, 삭제 · 미확정 제외.
    func finalizedResults() -> [(pill: IdentifiedPill, candidate: PillCandidateModel)] {
        let all = Dictionary(uniqueKeysWithValues: (pills + manualPills).map { ($0.index, $0) })
        return displayOrder.compactMap { index in
            guard let pill = all[index], let candidate = selectedCandidates[index] else { return nil }
            return (pill, candidate)
        }
    }

    /// 사용자가 지운 모델 알약의 번호(속성 추출 `pillId`) — `완료` 때 학습용 라벨로 보낸다(NM-568).
    /// 수동 추가 알약은 넣지 않는다(위치 행에 없는 번호라 서버가 400).
    func deletedModelPillIds() -> [Int] {
        pills.filter { deletedIndices.contains($0.index) }.compactMap { Int($0.pillId) }.sorted()
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

    /// 하나라도 확정하면 `완료` · `공유`를 켠다 — 모두 확정할 필요는 없다(빈 기록은 만들지 않는다).
    private func updateProgress() {
        let total = pills.count - deletedIndices.count + manualPills.count
        let done = identifiedIndices.count
        progressDoneLabel.text = "\(done) / \(total) 식별 완료"
        progressLeftLabel.text = "\(max(0, total - done))개 남음"
        progressLeftLabel.isHidden = done >= total
        progressBar.progress = total > 0 ? CGFloat(done) / CGFloat(total) : 0
        completeButton.setEnabled(done > 0)
        shareButton.setEnabled(done > 0)
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

            // 영역 테두리 · 번호 태그는 카드와 같은 색 — 카드와 번호로 짝을 짓는다.
            let accent = state(of: pill).tone.accent
            let boxView = UIView(frame: rect).then {
                $0.backgroundColor = .clear
                $0.layer.borderColor = accent.cgColor
                $0.layer.borderWidth = 2
                $0.layer.cornerRadius = 4
            }
            container.addSubview(boxView)

            let tag = UIView().then {
                $0.backgroundColor = accent
                $0.layer.cornerRadius = 4
                $0.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner]
            }
            let tagLabel = UILabel().then {
                $0.text = "\(number(of: pill.index))"
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

            boxViews[pill.index] = (boxView, tag, tagLabel)
        }
    }

    // MARK: - Actions

    /// 확정하지 않은 알약이 남았으면 종료 확인을 먼저 받는다. 모두 확정했으면 바로 저장.
    @objc private func completeTapped() {
        let unconfirmed = identificationSummary().unconfirmedCount
        guard unconfirmed > 0 else {
            onComplete?()
            return
        }
        let card = ConfirmCardView(
            title: "알약 식별을 종료할까요?",
            message: "확정하지 않은 \(unconfirmed)개는 기록에 남지 않아요",
            cancelTitle: "취소",
            confirmTitle: "종료"
        )
        presentConfirmCard(card, dismissOnBackgroundTap: false) { [weak self] in
            self?.onComplete?()
        }
    }

    // 공유 — 텍스트 복사 / PDF로 저장. 공유는 저장과 별개다(기록은 `완료`를 눌러야 남는다).
    @objc private func shareTapped() {
        let results = finalizedResults()
        guard !results.isEmpty else { return }
        let text = PillShareComposer.plainText(
            pills: results.map(\.pill),
            candidates: Dictionary(uniqueKeysWithValues: results.map { ($0.pill.index, $0.candidate) })
        )
        let sheet = ShareActionSheetVC(
            onCopyText: { [weak self] in
                guard let self else { return }
                AppAnalytics.track(.share(method: "copy_text", contentType: "pill_result"))
                UIPasteboard.general.string = text
                self.showToast("결과가 복사되었어요", above: self.bottomBar)
            },
            onSavePDF: { [weak self] in
                guard let self else { return }
                AppAnalytics.track(.share(method: "save_pdf", contentType: "pill_result"))
                guard let url = PillShareComposer.pdfURL(text: text) else {
                    self.showToast("PDF 생성에 실패했어요", above: self.bottomBar)
                    return
                }
                let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                activity.popoverPresentationController?.sourceView = self.shareButton
                activity.popoverPresentationController?.sourceRect = self.shareButton.bounds
                self.present(activity, animated: true)
            }
        )
        present(sheet, animated: false)
    }

    // MARK: - 저장 (NM-552)

    /// 기록 저장 중 — `완료`는 `저장 중…`, `공유`는 비활성, 뒤로도 막는다.
    func setSaving(_ isSaving: Bool) {
        var title = AttributedString(isSaving ? "저장 중…" : "완료")
        title.font = DSKitFontFamily.Pretendard.semiBold.font(size: 16)
        completeButton.configuration?.attributedTitle = title
        completeButton.setEnabled(!isSaving)
        shareButton.setEnabled(!isSaving)
        navBar.isUserInteractionEnabled = !isSaving
        if !isSaving { updateProgress() }
    }

    /// 저장 실패 — 통신 · 서버면 `나가기` / `다시 시도`, 400이면 `나가기`만(같은 요청은 같은 결과다).
    func showSaveFailure(canRetry: Bool, onExit: @escaping () -> Void, onRetry: @escaping () -> Void) {
        let title = "식별 결과를 저장하지 못했어요"
        guard canRetry else {
            DSAlertCardView.present(
                on: view,
                title: title,
                message: "이 결과는 기록에 남길 수 없어요",
                confirmTitle: "나가기",
                confirmed: onExit
            )
            return
        }
        let card = ConfirmCardView(
            title: title,
            message: "네트워크 연결을 확인하고 다시 시도해 주세요",
            cancelTitle: "나가기",
            confirmTitle: "다시 시도"
        )
        presentConfirmCard(card, dismissOnBackgroundTap: false, confirmed: onRetry)
        // ConfirmCardView 의 취소 자리가 `나가기`다 — dim 을 걷는 기본 동작 뒤에 이어서 나간다.
        let dismiss = card.onCancel
        card.onCancel = {
            dismiss?()
            onExit()
        }
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

// MARK: - Progress Bar

/// 진행 막대 — 높이 4, 트랙 Neutral100, 채움 Success500, 캡슐.
private final class ResultProgressBar: UIView {

    var progress: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    private let fill = UIView()

    init() {
        super.init(frame: .zero)
        backgroundColor = DSColor.Neutral._100
        layer.cornerRadius = 2
        clipsToBounds = true
        fill.backgroundColor = DSColor.Success._500
        fill.layer.cornerRadius = 2
        addSubview(fill)
        snp.makeConstraints { $0.height.equalTo(4) }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        UIView.animate(withDuration: 0.25) {
            self.fill.frame = CGRect(x: 0, y: 0, width: self.bounds.width * max(0, min(1, self.progress)), height: self.bounds.height)
        }
    }
}
