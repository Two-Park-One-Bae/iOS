import UIKit
import SnapKit
import Then
import DSKit
import Domain
import Kingfisher

// ⑧ 알약 수정 화면의 컬렉션뷰 구성요소.
// 후보 20개를 매 응답마다 UIStackView 로 재생성하던 구조가 UIScrollView.layoutSubviews +
// 대량 NSLayoutConstraint 활성화로 Severe Hang 을 유발해서, 셀 재사용 컬렉션뷰로 옮긴다.

// MARK: - 후보 셀

/// 후보 1개 (라디오 + 서버 낱알 썸네일 + 이름/회사 + ⓘ). 서브뷰는 init 에서 1회만 만들고
/// configure 로 내용만 갈아끼워 재사용한다(=행마다 새 뷰 생성 안 함).
final class CandidateCell: UICollectionViewCell {
    static let reuseID = "CandidateCell"

    private(set) var pillCode: String?
    var onInfoTap: (() -> Void)?

    private let card = UIView().then {
        $0.backgroundColor = DSColor.Neutral._0
        $0.layer.cornerRadius = 14
        $0.layer.borderWidth = 1
        $0.layer.borderColor = DSColor.Neutral._200.cgColor
    }
    private let ring = UIView().then {
        $0.layer.cornerRadius = 10
        $0.layer.borderWidth = 2
        $0.layer.borderColor = DSColor.Neutral._400.cgColor
    }
    private let dot = UIView().then {
        $0.backgroundColor = DSColor.Primary._500
        $0.layer.cornerRadius = 5
        $0.isHidden = true
    }
    private let thumb = UIImageView().then {
        $0.backgroundColor = DSColor.Neutral._100
        $0.layer.cornerRadius = 8
        $0.clipsToBounds = true
        $0.contentMode = .scaleAspectFill
    }
    private let nameLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 14)
        $0.textColor = DSColor.textPrimary
    }
    private let companyLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
        $0.textColor = DSColor.textTertiary
    }
    // 허가 취소·취하(REVOKED) 품목에만 노출. 기본 숨김 — configure에서 결정.
    private let licenseBadge = LicenseRevokedBadge().then { $0.isHidden = true }
    private let info = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        contentView.addSubview(card)
        card.snp.makeConstraints { $0.edges.equalToSuperview() }

        let radio = UIView()
        radio.addSubview(ring)
        ring.addSubview(dot)
        radio.snp.makeConstraints { $0.width.height.equalTo(20) }
        ring.snp.makeConstraints { $0.edges.equalToSuperview() }
        dot.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(10) }

        thumb.snp.makeConstraints { $0.width.equalTo(72); $0.height.equalTo(38) }

        // 이름 옆에 '허가 종료' 배지 — 이름이 길면 이름만 말줄임, 배지는 고정.
        let nameSpacer = UIView()
        let nameRow = UIStackView(arrangedSubviews: [nameLabel, licenseBadge, nameSpacer]).then {
            $0.axis = .horizontal
            $0.spacing = 6
            $0.alignment = .center
        }
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        licenseBadge.setContentHuggingPriority(.required, for: .horizontal)
        licenseBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        nameSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let texts = UIStackView(arrangedSubviews: [nameRow, companyLabel]).then {
            $0.axis = .vertical
            $0.spacing = 2
        }

        info.setImage(DSIcon.info.uiImage, for: .normal)
        info.tintColor = DSColor.Primary._500
        info.addAction(UIAction { [weak self] _ in self?.onInfoTap?() }, for: .touchUpInside)
        info.snp.makeConstraints { $0.width.height.equalTo(24) }

        let row = UIStackView(arrangedSubviews: [radio, thumb, texts, info]).then {
            $0.axis = .horizontal
            $0.spacing = 12
            $0.alignment = .center
        }
        card.addSubview(row)
        row.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(10)
            $0.leading.trailing.equalToSuperview().inset(12)
        }
    }

    func configure(candidate: PillCandidateModel, selected: Bool) {
        pillCode = candidate.pillCode
        nameLabel.text = candidate.pillName ?? "이름 미상"
        companyLabel.text = candidate.companyName ?? "-"
        licenseBadge.isHidden = candidate.licenseStatus != .revoked

        // 서버 낱알 이미지(pillImageUrl)를 Kingfisher로 로드. 작은 셀이라 표시 크기(72×38)로
        // 다운샘플 → 풀사이즈 디코드 낭비·메모리 절감.
        thumb.kf.cancelDownloadTask()
        thumb.image = nil
        if let urlString = candidate.pillImageUrl, let url = URL(string: urlString) {
            thumb.kf.setImage(
                with: url,
                options: [
                    .processor(DownsamplingImageProcessor(size: CGSize(width: 72, height: 38))),
                    .scaleFactor(UIScreen.main.scale),
                    .cacheOriginalImage,
                    .transition(.fade(0.2)),
                ]
            )
        }
        setSelected(selected)
    }

    func setSelected(_ selected: Bool) {
        dot.isHidden = !selected
        ring.layer.borderColor = (selected ? DSColor.Primary._500 : DSColor.Neutral._400).cgColor
        card.layer.borderColor = (selected ? DSColor.Primary._500 : DSColor.Neutral._200).cgColor
        card.layer.borderWidth = selected ? 2 : 1
        card.backgroundColor = selected ? DSColor.Primary._50 : DSColor.Neutral._0
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumb.kf.cancelDownloadTask()
        thumb.image = nil
        onInfoTap = nil
        pillCode = nil
        licenseBadge.isHidden = true
    }
}

// MARK: - 허가 종료 배지

/// 허가 취소·취하(REVOKED) 품목 표시 배지 — 품목명 옆 (XGm3Z).
/// warning-50 배경 / warning-100 테두리 1px / warning-700 텍스트 10pt, radius 4, padding (2,6).
final class LicenseRevokedBadge: UIView {
    init() {
        super.init(frame: .zero)
        backgroundColor = DSColor.Warning._50
        layer.cornerRadius = 4
        layer.borderWidth = 1
        layer.borderColor = DSColor.Warning._100.cgColor

        let label = UILabel().then {
            $0.text = "허가 종료"
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 10)
            $0.textColor = DSColor.Warning._700
        }
        addSubview(label)
        label.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(2)
            $0.leading.trailing.equalToSuperview().inset(6)
        }
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - 속성 카드 호스트 셀

/// 섹션 0의 단일 셀 — VC가 소유·구성하는 속성 편집 카드(칩·패널·각인 필드)를 그대로 담는다.
/// 카드가 VC 소유라 재사용 풀을 오염시키지 않도록 전용 reuseID로만 쓴다.
final class AttributeHostCell: UICollectionViewCell {
    static let reuseID = "AttributeHostCell"

    private weak var hosted: UIView?

    /// 제공된 카드 뷰를 contentView에 꽉 채워 붙인다. 이미 붙어 있으면 no-op(퍼스트 리스폰더 유지).
    func host(_ view: UIView) {
        if hosted === view, view.superview == contentView { return }
        view.removeFromSuperview()
        contentView.addSubview(view)
        view.snp.remakeConstraints { $0.edges.equalToSuperview() }
        hosted = view
    }
}

// MARK: - 로딩 / 빈 상태 셀

/// "후보를 찾고 있어요" 스피너 셀.
final class CandidateLoadingCell: UICollectionViewCell {
    static let reuseID = "CandidateLoadingCell"

    private let spinner = UIActivityIndicatorView(style: .medium).then {
        $0.color = DSColor.textTertiary
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let label = UILabel().then {
            $0.text = "후보를 찾고 있어요"
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
            $0.textColor = DSColor.textTertiary
            $0.textAlignment = .center
        }
        contentView.addSubview(spinner)
        contentView.addSubview(label)
        spinner.snp.makeConstraints {
            $0.top.equalToSuperview().offset(32)
            $0.centerX.equalToSuperview()
        }
        label.snp.makeConstraints {
            $0.top.equalTo(spinner.snp.bottom).offset(10)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview().inset(8)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow != nil { spinner.startAnimating() } else { spinner.stopAnimating() }
    }
}

/// "조건에 맞는 후보가 없어요" 빈 상태 셀.
final class CandidateEmptyCell: UICollectionViewCell {
    static let reuseID = "CandidateEmptyCell"

    override init(frame: CGRect) {
        super.init(frame: frame)
        let circle = UIView().then {
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = 32
        }
        circle.snp.makeConstraints { $0.width.height.equalTo(64) }
        let icon = UIImageView().then {
            $0.image = DSIcon.searchX.uiImage
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
        contentView.addSubview(circle)
        contentView.addSubview(title)
        contentView.addSubview(desc)
        circle.snp.makeConstraints {
            $0.top.equalToSuperview().offset(24)
            $0.centerX.equalToSuperview()
        }
        title.snp.makeConstraints {
            $0.top.equalTo(circle.snp.bottom).offset(14)
            $0.leading.trailing.equalToSuperview()
        }
        desc.snp.makeConstraints {
            $0.top.equalTo(title.snp.bottom).offset(6)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview().inset(16)
        }
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - 후보 섹션 헤더 ("후보 / 실시간")

final class CandidateHeaderView: UICollectionReusableView {
    static let reuseID = "CandidateHeaderView"

    override init(frame: CGRect) {
        super.init(frame: frame)
        let title = UILabel().then {
            $0.text = "후보"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 15)
            $0.textColor = DSColor.textPrimary
        }
        let zap = UIImageView().then {
            $0.image = DSIcon.zap.uiImage
            $0.tintColor = DSColor.Primary._500
            $0.contentMode = .scaleAspectFit
        }
        zap.snp.makeConstraints { $0.width.height.equalTo(13) }
        let hint = UILabel().then {
            $0.text = "실시간"
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 12)
            $0.textColor = DSColor.Primary._600
        }
        let hintStack = UIStackView(arrangedSubviews: [zap, hint]).then {
            $0.axis = .horizontal; $0.spacing = 4; $0.alignment = .center
        }
        let row = UIStackView(arrangedSubviews: [title, UIView(), hintStack]).then {
            $0.axis = .horizontal; $0.alignment = .center
        }
        addSubview(row)
        row.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.leading.trailing.equalToSuperview()
        }
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - 후보 섹션 푸터 (선택 안내)

/// "후보를 선택하면 확인 버튼이 나타나요" 안내. 결과가 있고 아직 선택 전일 때만 문구를 보인다.
final class SelectHintFooter: UICollectionReusableView {
    static let reuseID = "SelectHintFooter"

    private let label = UILabel().then {
        $0.text = "후보를 선택하면 확인 버튼이 나타나요"
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
        $0.textColor = DSColor.textTertiary
        $0.textAlignment = .center
    }

    private lazy var collapse = heightAnchor.constraint(equalToConstant: 0.5)

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(label)
        label.snp.makeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview().inset(4)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    /// 결과가 있고 아직 선택 전일 때만 문구 노출. 그 외엔 높이를 접어 빈 여백을 없앤다.
    func setVisible(_ visible: Bool) {
        label.isHidden = !visible
        collapse.isActive = !visible
    }
}
