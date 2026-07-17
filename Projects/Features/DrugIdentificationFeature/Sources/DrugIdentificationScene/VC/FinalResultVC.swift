import UIKit
import SnapKit
import Then
import DSKit
import Domain

// ⑨ 최종 결과 리스트 — 모든 알약 식별 완료 후 확정 결과를 보여주는 읽기전용 화면 (NM-136)
final class FinalResultVC: UIViewController {

    // MARK: - Callbacks

    var onShare: (() -> Void)?
    var onComplete: (() -> Void)?
    var onBackTapped: (() -> Void)?
    // 카드 탭 → 세부정보 진입 (pillCode, 썸네일)
    var onSelectDetail: ((String, String?) -> Void)?

    // MARK: - Properties

    private let pills: [IdentifiedPill]
    private let candidates: [Int: PillCandidateModel]

    // MARK: - UI

    private lazy var navBar = DSNavBar(title: "식별 결과").then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let scrollView = UIScrollView().then {
        $0.showsVerticalScrollIndicator = false
    }

    private let contentStack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 12
        $0.isLayoutMarginsRelativeArrangement = true
        $0.layoutMargins = UIEdgeInsets(top: 12, left: 20, bottom: 20, right: 20)
    }

    private let footer = UIView().then {
        $0.backgroundColor = DSColor.bgApp
        $0.layer.shadowColor = DSColor.textPrimary.cgColor
        $0.layer.shadowOpacity = 0.1
        $0.layer.shadowOffset = CGSize(width: 0, height: -4)
        $0.layer.shadowRadius = 16
    }

    private let shareButton = SecondaryButton(title: "공유")
    private let completeButton = PrimaryButton(title: "완료")

    // MARK: - Init

    init(pills: [IdentifiedPill], candidates: [Int: PillCandidateModel]) {
        self.pills = pills
        self.candidates = candidates
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
        setContent()
    }

    // MARK: - Setup

    private func setUI() {
        view.backgroundColor = DSColor.bgApp
        navBar.onBackTapped = { [weak self] in self?.onBackTapped?() }
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
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(footer.snp.top)
        }
        contentStack.snp.makeConstraints {
            $0.edges.equalTo(scrollView.contentLayoutGuide)
            $0.width.equalTo(scrollView.frameLayoutGuide)
        }

        setupFooter()
    }

    private func setupFooter() {
        let disclaimer = UILabel().then {
            $0.text = "본 결과는 참고용입니다. 투약 전 처방·약품 라벨을 확인하세요."
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 11)
            $0.textColor = DSColor.textTertiary
            $0.textAlignment = .center
            $0.numberOfLines = 0
        }

        let buttons = UIStackView(arrangedSubviews: [shareButton, completeButton]).then {
            $0.axis = .horizontal
            $0.spacing = 10
            $0.distribution = .fillEqually
        }
        completeButton.snp.makeConstraints { $0.height.equalTo(52) }

        let stack = UIStackView(arrangedSubviews: [disclaimer, buttons]).then {
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

    private func setActions() {
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        completeButton.addTarget(self, action: #selector(completeTapped), for: .touchUpInside)
    }

    // MARK: - Content

    private func setContent() {
        contentStack.addArrangedSubview(makeSummary(count: pills.count))
        for pill in pills {
            guard let candidate = candidates[pill.index] else { continue }
            contentStack.addArrangedSubview(makeCard(pill: pill, candidate: candidate))
        }
    }

    private func makeSummary(count: Int) -> UIView {
        let icon = UIImageView().then {
            $0.image = DSIcon.checkCircle.uiImage
            $0.tintColor = DSColor.Secondary._500
            $0.contentMode = .scaleAspectFit
        }
        icon.snp.makeConstraints { $0.width.height.equalTo(22) }

        let label = UILabel().then {
            $0.text = "총 \(count)개 식별 완료"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 15)
            $0.textColor = DSColor.Secondary._700
        }

        return UIStackView(arrangedSubviews: [icon, label]).then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.alignment = .center
            $0.isLayoutMarginsRelativeArrangement = true
            $0.layoutMargins = UIEdgeInsets(top: 0, left: 2, bottom: 4, right: 2)
        }
    }

    private func makeCard(pill: IdentifiedPill, candidate: PillCandidateModel) -> UIView {
        let card = UIView().then {
            $0.backgroundColor = DSColor.surface
            $0.layer.cornerRadius = 14
            $0.layer.shadowColor = DSColor.textPrimary.cgColor
            $0.layer.shadowOpacity = 0.04
            $0.layer.shadowOffset = CGSize(width: 0, height: 1)
            $0.layer.shadowRadius = 6
        }

        let thumb = UIImageView().then {
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = 12
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFit
            $0.image = pill.thumbnail
        }
        thumb.snp.makeConstraints { $0.width.height.equalTo(48) }

        let name = UILabel().then {
            $0.text = candidate.pillName ?? "이름 미상"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 15)
            $0.textColor = DSColor.textPrimary
        }
        let company = UILabel().then {
            $0.text = candidate.companyName ?? "-"
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
            $0.textColor = DSColor.textSecondary
        }
        let texts = UIStackView(arrangedSubviews: [name, company]).then {
            $0.axis = .vertical
            $0.spacing = 3
        }
        name.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // 세부정보 진입 안내 아이콘 (탭 → 세부정보)
        let info = UIImageView().then {
            $0.image = UIImage(systemName: "info.circle")
            $0.tintColor = DSColor.Primary._500
            $0.contentMode = .scaleAspectFit
        }
        info.snp.makeConstraints { $0.width.height.equalTo(22) }

        let row = UIStackView(arrangedSubviews: [thumb, texts, info]).then {
            $0.axis = .horizontal
            $0.spacing = 12
            $0.alignment = .center
        }
        card.addSubview(row)
        row.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(14)
            $0.leading.trailing.equalToSuperview().inset(14)
        }

        // 카드 전체를 탭 영역으로 — 세부정보 진입
        let tapButton = UIButton(type: .system)
        let pillCode = candidate.pillCode
        let imageUrl = candidate.pillImageUrl
        tapButton.addAction(UIAction { [weak self] _ in
            self?.onSelectDetail?(pillCode, imageUrl)
        }, for: .touchUpInside)
        card.addSubview(tapButton)
        tapButton.snp.makeConstraints { $0.edges.equalToSuperview() }
        return card
    }

    // MARK: - Actions

    @objc private func shareTapped() { onShare?() }
    @objc private func completeTapped() { onComplete?() }
}
