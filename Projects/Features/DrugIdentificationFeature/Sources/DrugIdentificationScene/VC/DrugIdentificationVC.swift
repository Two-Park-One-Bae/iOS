import UIKit
import SnapKit
import Then
import DSKit

// ⑤ 인식 결과 — 촬영 사진(bbox 오버레이) + 알약 목록 + 결과 확인 푸터
public final class DrugIdentificationVC: UIViewController {

    // MARK: - Callbacks

    var onSelectPill: ((IdentifiedPill) -> Void)?
    var onConfirm: (() -> Void)?
    var onBackTapped: (() -> Void)?

    // MARK: - Properties

    private let pills: [IdentifiedPill]
    private let capturedImage: UIImage
    private let photoSize: CGFloat = 300

    private var rowViews: [Int: PillResultRowView] = [:]
    private var identifiedIndices = Set<Int>()
    private var deletedIndices = Set<Int>()

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
        navBar.onBackTapped = { [weak self] in self?.onBackTapped?() }
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
        let listTitle = UILabel().then {
            $0.text = "알약 \(pills.count)개를 찾았어요"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 15)
            $0.textColor = DSColor.textPrimary
        }

        let listStack = UIStackView(arrangedSubviews: [listTitle]).then {
            $0.axis = .vertical
            $0.spacing = 10
            $0.isLayoutMarginsRelativeArrangement = true
            $0.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        }

        for pill in pills {
            let row = PillResultRowView(pill: pill)
            row.onTap = { [weak self] in self?.onSelectPill?(pill) }
            row.onMenu = { [weak self] in self?.showRowMenu(for: pill, anchor: row) }
            rowViews[pill.index] = row
            listStack.addArrangedSubview(row)
        }

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
        let dim = UIView(frame: view.bounds).then { $0.backgroundColor = DSColor.Neutral._900.withAlphaComponent(0.6) }
        addDismissTap(to: dim)

        let card = DeleteConfirmCardView()
        card.onCancel = { dim.removeFromSuperview() }
        card.onDelete = { [weak self] in
            dim.removeFromSuperview()
            self?.deletePill(pill)
        }
        dim.addSubview(card)
        view.addSubview(dim)
        card.snp.makeConstraints { $0.center.equalToSuperview() }
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
        deletedIndices.insert(pill.index)
        identifiedIndices.remove(pill.index)
        updateProgress()
    }

    // MARK: - Selection

    func applySelection(pillIndex: Int, name: String) {
        rowViews[pillIndex]?.showSelected(name: name)
        identifiedIndices.insert(pillIndex)
        updateProgress()
    }

    private func updateProgress() {
        let total = pills.count - deletedIndices.count
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
        }
    }

    // MARK: - Actions

    @objc private func confirmTapped() {
        onConfirm?()
    }
}

// MARK: - Overlay 빈 영역 탭 감지

extension DrugIdentificationVC: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 오버레이(scrim/dim) 자체를 탭했을 때만 닫기 — 메뉴/카드 내부 터치는 통과
        touch.view === gestureRecognizer.view
    }
}
