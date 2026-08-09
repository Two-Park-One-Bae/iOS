import UIKit
import Kingfisher
import SnapKit
import Then
import DSKit

// ⑧-i/j/k 후보 이미지 비교 (NM-354)
//
// 후보 낱알 원본(pillImageUrl, NM-356) 위 / 촬영한 알약 크롭 아래를 세로로 대조하는 풀스크린 라이트박스.
// 후보 카드 썸네일 탭에서 진입하며, 탭한 위치에서 확대되며 뜬다(PillImageZoomTransition).
//
// 3상태(입력으로 결정):
//  - 비교        : 후보 원본 + 촬영 크롭 둘 다
//  - 크롭 없음    : 촬영 크롭이 없으면(수동 추가 등) 후보 카드만 단독
//  - 원본 폴백    : 후보 원본이 없거나(nil) CDN 404면 후보 칸을 '원본 이미지 없음' 플레이스홀더로
final class PillImageComparisonVC: UIViewController {

    var onClose: (() -> Void)?

    private let candidateImageURL: URL?
    private let croppedImage: UIImage?
    // transitioningDelegate는 weak라 여기서 강하게 소유해야 확대 트랜지션이 유지된다.
    private let zoomTransition: PillImageZoomTransition

    // 확대 트랜지션이 목표 프레임을 재려면 후보 이미지 뷰가 필요하므로 노출한다.
    private(set) lazy var candidateImageView = UIImageView().then {
        $0.contentMode = .scaleAspectFit
        $0.clipsToBounds = true
    }

    // MARK: - Init

    init(candidateImageURL: URL?, croppedImage: UIImage?, sourceFrame: CGRect, sourceImage: UIImage?) {
        self.candidateImageURL = candidateImageURL
        self.croppedImage = croppedImage
        self.zoomTransition = PillImageZoomTransition(sourceFrame: sourceFrame, sourceImage: sourceImage)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        transitioningDelegate = zoomTransition
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: 0xEEF2F7)
        setLayout()
        loadCandidateImage()
    }

    // MARK: - Layout

    private func setLayout() {
        // 닫기 버튼 (우측 상단)
        let closeButton = UIButton(type: .system).then {
            $0.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)), for: .normal)
            $0.tintColor = UIColor(hex: 0x1E293B)
            $0.addAction(UIAction { [weak self] _ in self?.close() }, for: .touchUpInside)
        }
        view.addSubview(closeButton)
        closeButton.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(6)
            $0.trailing.equalToSuperview().inset(16)
            $0.width.height.equalTo(44)
        }

        // 카드 스택 (세로 중앙)
        let stack = UIStackView().then {
            $0.axis = .vertical
            $0.spacing = 20
            $0.alignment = .fill
        }
        view.addSubview(stack)
        stack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.centerY.equalToSuperview()
            $0.top.greaterThanOrEqualTo(closeButton.snp.bottom).offset(8)
        }

        // 후보 원본 카드 (항상 표시 — 이미지 없으면 플레이스홀더로 폴백)
        stack.addArrangedSubview(makeCard(label: "후보 이미지", content: candidateContentView()))

        // 촬영 크롭 카드 (크롭이 있을 때만)
        if let crop = croppedImage {
            stack.addArrangedSubview(makeCard(label: "촬영한 알약", content: croppedContentView(crop)))
        }
    }

    // 카드 = 흰 배경 + 라운드 + 테두리 + 그림자, 상단-좌측에 라벨 칩(절대배치)
    private func makeCard(label: String, content: UIView) -> UIView {
        let card = UIView().then {
            $0.backgroundColor = .white
            $0.layer.cornerRadius = 16
            $0.layer.borderWidth = 1
            $0.layer.borderColor = UIColor(hex: 0xE2E8F0).cgColor
            $0.layer.shadowColor = UIColor(hex: 0x0F172A).cgColor
            $0.layer.shadowOpacity = 0.14
            $0.layer.shadowRadius = 12
            $0.layer.shadowOffset = CGSize(width: 0, height: 8)
        }
        // 이미지는 카드 라운드로 클리핑되어야 하므로 별도 클립 컨테이너에 담는다.
        let clipBox = UIView().then {
            $0.layer.cornerRadius = 16
            $0.clipsToBounds = true
            $0.backgroundColor = .white
        }
        card.addSubview(clipBox)
        clipBox.snp.makeConstraints { $0.edges.equalToSuperview() }
        clipBox.addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.height.equalTo(186)
        }

        let chip = makeLabelChip(label)
        card.addSubview(chip)
        chip.snp.makeConstraints {
            $0.top.leading.equalToSuperview().offset(12)
        }
        return card
    }

    private func makeLabelChip(_ text: String) -> UIView {
        let chip = UIView().then {
            $0.backgroundColor = UIColor(hex: 0x0F172A, alpha: 0.8)
            $0.layer.cornerRadius = 12
        }
        let label = UILabel().then {
            $0.text = text
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
            $0.textColor = .white
        }
        chip.addSubview(label)
        label.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(5)
            $0.leading.trailing.equalToSuperview().inset(12)
        }
        return chip
    }

    // 후보 원본 이미지 뷰(로드 실패 시 loadCandidateImage에서 플레이스홀더로 교체)
    private func candidateContentView() -> UIView {
        candidateImageView.backgroundColor = UIColor(hex: 0xF8FAFC)
        return candidateImageView
    }

    // 촬영 크롭 = 그리드 배경 위에 크롭 이미지(aspectFit)
    private func croppedContentView(_ crop: UIImage) -> UIView {
        let container = UIView()
        let grid = UIImageView().then {
            $0.image = UIImage(named: "PillBackground", in: .module, compatibleWith: nil)
            $0.contentMode = .scaleAspectFill
            $0.clipsToBounds = true
        }
        container.addSubview(grid)
        grid.snp.makeConstraints { $0.edges.equalToSuperview() }

        let pill = UIImageView(image: crop).then {
            $0.contentMode = .scaleAspectFit
        }
        container.addSubview(pill)
        pill.snp.makeConstraints { $0.edges.equalToSuperview().inset(16) }
        return container
    }

    // 원본 없음(nil URL·404) 폴백 플레이스홀더 — 후보 이미지 뷰 자리에 덮어 표시
    private func showCandidatePlaceholder() {
        guard let superview = candidateImageView.superview else { return }
        candidateImageView.isHidden = true
        let placeholder = UIView().then { $0.backgroundColor = UIColor(hex: 0xF1F5F9) }
        let stack = UIStackView().then {
            $0.axis = .vertical
            $0.alignment = .center
            $0.spacing = 10
        }
        let icon = UIImageView(image: UIImage(systemName: "photo")).then {
            $0.tintColor = UIColor(hex: 0x94A3B8)
            $0.contentMode = .scaleAspectFit
        }
        icon.snp.makeConstraints { $0.width.height.equalTo(42) }
        let label = UILabel().then {
            $0.text = "원본 이미지 없음"
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
            $0.textColor = UIColor(hex: 0x94A3B8)
        }
        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(label)
        placeholder.addSubview(stack)
        stack.snp.makeConstraints { $0.center.equalToSuperview() }
        superview.addSubview(placeholder)
        placeholder.snp.makeConstraints { $0.edges.equalTo(candidateImageView) }
    }

    private func loadCandidateImage() {
        guard let url = candidateImageURL else {
            showCandidatePlaceholder()
            return
        }
        candidateImageView.kf.setImage(with: url, options: [.transition(.fade(0.2))]) { [weak self] result in
            // CDN 404 = 이미지 없음 → 플레이스홀더 폴백(부재 규약 NM-347).
            if case .failure = result { self?.showCandidatePlaceholder() }
        }
    }

    // MARK: - Actions

    private func close() {
        onClose?()
        dismiss(animated: true)
    }
}

// MARK: - Hex helper

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
