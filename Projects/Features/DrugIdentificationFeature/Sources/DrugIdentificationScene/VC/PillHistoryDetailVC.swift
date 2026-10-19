import UIKit
import Combine
import SnapKit
import Then
import DSKit
import Domain
import Core
import Kingfisher

// 기록 상세 (NM-552, 디자인 `oevZZ` · 더보기 `qKfjd` · 조회 중 `bCyqr`).
// 식별 시각 · 알약 목록 · `공유` · 면책 고지. `완료` 버튼은 없다 — `뒤로`로 나간다.
final class PillHistoryDetailVC: UIViewController {

    // MARK: - Callbacks

    var onBackTapped: (() -> Void)?
    var onSelectDetail: ((String, LicenseStatus) -> Void)?
    /// 지웠을 때 — 들어온 화면으로 돌아간다
    var onDeleted: (() -> Void)?
    /// 없어진 기록 — 들어온 화면으로 돌아가 `기록을 찾을 수 없어요`를 띄운다
    var onNotFound: (() -> Void)?

    // MARK: - Dependencies

    private let viewModel: PillHistoryDetailViewModel
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private let retrySubject = PassthroughSubject<Void, Never>()
    private let deleteSubject = PassthroughSubject<Void, Never>()
    private var cancelBag = Set<AnyCancellable>()
    private var history: PillHistoryModel?

    // MARK: - UI

    private lazy var navBar = DSNavBar(title: "식별 기록").then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let moreButton = UIButton(type: .system).then {
        $0.setImage(DSIcon.moreVertical.uiImage, for: .normal)
        $0.tintColor = DSColor.textPrimary
        $0.accessibilityLabel = "더보기"
    }

    private let scrollView = UIScrollView().then {
        $0.showsVerticalScrollIndicator = false
    }

    private let contentStack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 10
        $0.isLayoutMarginsRelativeArrangement = true
        $0.layoutMargins = UIEdgeInsets(top: 8, left: 20, bottom: 20, right: 20)
    }

    private let dateLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 13)
        $0.textColor = DSColor.textSecondary
    }

    private let listStack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 10
    }

    private let shareButton = PrimaryButton(title: "공유")
    // 하단 바 — 판 없이 `공유` 캡슐 + 고지(V2.1.0 `IkyB0`).
    private lazy var footer = DSBottomBar(buttons: [shareButton], disclaimer: PillDisclaimer.notice).then {
        $0.backgroundColor = DSColor.surface
    }

    // MARK: - Init

    init(viewModel: PillHistoryDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = DSColor.surface
        setLayout()
        bind()
        viewDidLoadSubject.send(())
    }

    // MARK: - Layout

    private func setLayout() {
        [navBar, scrollView, footer].forEach(view.addSubview)
        scrollView.addSubview(contentStack)

        navBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
        }
        navBar.onBackTapped = { [weak self] in self?.onBackTapped?() }

        // DSNavBar 오른쪽은 제목 가운데 정렬용 빈 칸 — 그 자리에 더보기를 얹는다.
        navBar.addSubview(moreButton)
        moreButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(8)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(44)
        }
        moreButton.addAction(UIAction { [weak self] _ in self?.showMenu() }, for: .touchUpInside)

        scrollView.snp.makeConstraints {
            $0.top.equalTo(navBar.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(footer.snp.top)
        }
        contentStack.snp.makeConstraints {
            $0.edges.equalTo(scrollView.contentLayoutGuide)
            $0.width.equalTo(scrollView.frameLayoutGuide)
        }

        let calendarIcon = UIImageView(image: DSIcon.calendar.uiImage).then {
            $0.tintColor = DSColor.textSecondary
            $0.contentMode = .scaleAspectFit
        }
        calendarIcon.snp.makeConstraints { $0.width.height.equalTo(16) }
        let dateRow = UIStackView(arrangedSubviews: [calendarIcon, dateLabel, UIView()]).then {
            $0.axis = .horizontal
            $0.spacing = 6
            $0.alignment = .center
            $0.isLayoutMarginsRelativeArrangement = true
            $0.layoutMargins = UIEdgeInsets(top: 0, left: 2, bottom: 4, right: 2)
        }
        contentStack.addArrangedSubview(dateRow)
        contentStack.addArrangedSubview(listStack)

        // 고지 문구는 식별 결과 화면과 같다 (Guideline 1.4.1) — 버튼 아래.
        shareButton.addAction(UIAction { [weak self] _ in self?.shareTapped() }, for: .touchUpInside)
        footer.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }

    // MARK: - Bind

    private func bind() {
        let output = viewModel.transform(input: .init(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            retry: retrySubject.eraseToAnyPublisher(),
            delete: deleteSubject.eraseToAnyPublisher()
        ))
        dateLabel.text = output.identifiedAtText

        output.state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.render($0) }
            .store(in: &cancelBag)

        output.deleted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.onDeleted?() }
            .store(in: &cancelBag)

        output.deleteFailed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                self.showToast("기록을 삭제하지 못했어요", above: self.footer)
            }
            .store(in: &cancelBag)
    }

    // MARK: - Render

    private func render(_ state: PillHistoryDetailViewModel.State) {
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        history = nil

        switch state {
        case .loading(let count):
            shareButton.setEnabled(false)
            for _ in 0..<max(count, 1) { listStack.addArrangedSubview(makePlaceholderRow()) }
        case .loaded(let history):
            self.history = history
            shareButton.setEnabled(true)
            history.pills.forEach { listStack.addArrangedSubview(makeRow($0)) }
        case .failed:
            shareButton.setEnabled(false)
            listStack.addArrangedSubview(makeFailedView())
        case .notFound:
            shareButton.setEnabled(false)
            onNotFound?()
        }
    }

    // MARK: - Views

    /// 낱알 사진 · 품목명(+ 허가 종료) · 업체명 · ⓘ. 행을 누르면 세부정보.
    private func makeRow(_ pill: PillHistoryPillModel) -> UIView {
        let card = makeCard()

        let thumb = UIImageView().then {
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = 6
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFit
        }
        // 식약처 썸네일 비율(256 × 140) 그대로 — 높이 28.
        thumb.snp.makeConstraints {
            $0.height.equalTo(28)
            $0.width.equalTo(thumb.snp.height).dividedBy(CandidateCell.thumbnailAspect)
        }
        // 이미지가 없는 품목은 회색 자리 표시로 둔다(후보 카드와 같다).
        if let urlString = pill.pillThumbnailUrl, let url = URL(string: urlString) {
            thumb.kf.setImage(
                with: url,
                options: [
                    .processor(DownsamplingImageProcessor(size: CGSize(width: 51, height: 28))),
                    .scaleFactor(UIScreen.main.scale),
                    .cacheOriginalImage,
                    .transition(.fade(0.2)),
                ]
            )
        }

        let name = UILabel().then {
            $0.text = pill.pillName
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 15)
            $0.textColor = DSColor.textPrimary
            $0.lineBreakMode = .byTruncatingTail
            $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        let badge = LicenseRevokedBadge().then {
            $0.isHidden = pill.licenseStatus != .revoked
        }
        let nameRow = UIStackView(arrangedSubviews: [name, badge, UIView()]).then {
            $0.axis = .horizontal
            $0.spacing = 6
            $0.alignment = .center
        }
        let company = UILabel().then {
            $0.text = pill.companyName
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
            $0.textColor = DSColor.textSecondary
        }
        let texts = UIStackView(arrangedSubviews: [nameRow, company]).then {
            $0.axis = .vertical
            $0.spacing = 3
        }
        let info = UIImageView(image: DSIcon.info.uiImage).then {
            $0.tintColor = DSColor.Primary._500
            $0.contentMode = .scaleAspectFit
        }
        info.snp.makeConstraints { $0.width.height.equalTo(20) }

        let row = UIStackView(arrangedSubviews: [thumb, texts, info]).then {
            $0.axis = .horizontal
            $0.spacing = 12
            $0.alignment = .center
        }
        card.addSubview(row)
        row.snp.makeConstraints { $0.edges.equalToSuperview().inset(14) }

        let tapButton = UIButton(type: .system)
        tapButton.addAction(UIAction { [weak self] _ in
            AppAnalytics.track(.buttonTap(target: "pill_detail", screen: "history_detail"))
            self?.onSelectDetail?(pill.pillCode, pill.licenseStatus)
        }, for: .touchUpInside)
        card.addSubview(tapButton)
        tapButton.snp.makeConstraints { $0.edges.equalToSuperview() }
        return card
    }

    /// 조회 중 — 알약 수만큼 회색 막대 행.
    private func makePlaceholderRow() -> UIView {
        let card = makeCard()
        let thumb = makeBar(width: 48, height: 28, radius: 6)
        let line1 = makeBar(width: 140, height: 12, radius: 4)
        let line2 = makeBar(width: 80, height: 10, radius: 4)
        let texts = UIStackView(arrangedSubviews: [line1, line2]).then {
            $0.axis = .vertical
            $0.spacing = 8
            $0.alignment = .leading
        }
        let row = UIStackView(arrangedSubviews: [thumb, texts, UIView()]).then {
            $0.axis = .horizontal
            $0.spacing = 12
            $0.alignment = .center
        }
        card.addSubview(row)
        row.snp.makeConstraints { $0.edges.equalToSuperview().inset(14) }
        return card
    }

    private func makeBar(width: CGFloat, height: CGFloat, radius: CGFloat) -> UIView {
        UIView().then {
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = radius
            $0.snp.makeConstraints {
                $0.width.equalTo(width)
                $0.height.equalTo(height)
            }
        }
    }

    /// 유리 목록 카드(r20).
    private func makeCard() -> UIView {
        let card = UIView()
        let surface = DSSurfaceView(spec: .glassListCard)
        surface.frame = card.bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        card.addSubview(surface)
        return card
    }

    /// 조회 실패 — 알약 탭 불러오기 실패와 같은 모양.
    private func makeFailedView() -> UIView {
        let label = UILabel().then {
            $0.text = "기록을 불러오지 못했어요"
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 14)
            $0.textColor = DSColor.textSecondary
            $0.textAlignment = .center
        }
        let button = TextButton(title: "다시 시도")
        button.addAction(UIAction { [weak self] _ in self?.retrySubject.send(()) }, for: .touchUpInside)
        return UIStackView(arrangedSubviews: [label, button]).then {
            $0.axis = .vertical
            $0.spacing = 4
            $0.alignment = .center
            $0.isLayoutMarginsRelativeArrangement = true
            $0.layoutMargins = UIEdgeInsets(top: 60, left: 0, bottom: 0, right: 0)
        }
    }

    // MARK: - More Menu (⋮ 삭제)

    private func showMenu() {
        let scrim = UIView(frame: view.bounds).then { $0.backgroundColor = .clear }
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissMenu(_:)))
        tap.delegate = self
        scrim.addGestureRecognizer(tap)

        let menu = PillActionMenuView(showsEdit: false)
        menu.onDelete = { [weak self] in
            scrim.removeFromSuperview()
            self?.showDeleteConfirm()
        }
        scrim.addSubview(menu)
        view.addSubview(scrim)

        let anchorFrame = moreButton.convert(moreButton.bounds, to: scrim)
        menu.snp.makeConstraints {
            $0.trailing.equalTo(scrim.snp.leading).offset(anchorFrame.maxX - 6)
            $0.top.equalTo(scrim.snp.top).offset(anchorFrame.maxY - 4)
        }
    }

    @objc private func dismissMenu(_ sender: UITapGestureRecognizer) {
        sender.view?.removeFromSuperview()
    }

    private func showDeleteConfirm() {
        let card = ConfirmCardView(
            title: "이 기록을 삭제할까요?",
            message: "삭제하면 되돌릴 수 없어요",
            cancelTitle: "취소",
            confirmTitle: "삭제",
            isDestructive: true
        )
        presentConfirmCard(card, dismissOnBackgroundTap: false) { [weak self] in
            self?.deleteSubject.send(())
        }
    }

    // MARK: - Share

    // 식별 결과와 같은 규칙 — 텍스트 복사 / PDF로 저장.
    private func shareTapped() {
        guard let history else { return }
        let text = PillShareComposer.plainText(history: history)
        let sheet = ShareActionSheetVC(
            onCopyText: { [weak self] in
                guard let self else { return }
                AppAnalytics.track(.share(method: "copy_text", contentType: "pill_history"))
                UIPasteboard.general.string = text
                self.showToast("결과가 복사되었어요", above: self.footer)
            },
            onSavePDF: { [weak self] in
                guard let self else { return }
                AppAnalytics.track(.share(method: "save_pdf", contentType: "pill_history"))
                guard let url = PillShareComposer.pdfURL(text: text) else {
                    self.showToast("PDF 생성에 실패했어요", above: self.footer)
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
}

// MARK: - UIGestureRecognizerDelegate

extension PillHistoryDetailVC: UIGestureRecognizerDelegate {
    // 메뉴 바깥 빈 곳을 눌렀을 때만 닫는다 — 메뉴 행의 터치를 가로채면 `삭제`가 삼켜진다.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        touch.view === gestureRecognizer.view
    }
}
