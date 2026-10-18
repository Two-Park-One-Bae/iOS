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

/// 후보 카드 1개 — V2.1.0 2열 격자(NM-588 ②). 서브뷰는 init 에서 1회만 만들고 configure 로 내용만 갈아끼운다.
///
/// 유리 목록 카드(r20, padding 7 · 10 · 8 · 10, gap 5)
/// - 낱알 사진: 카드 폭 · r12, 식약처 썸네일 비율(256 × 140) 그대로 — 자르지도 비우지도 않는다. 오른쪽 위 `크게 보기`(유리 아이콘 버튼),
///   허가 종료 배지는 사진 왼쪽 위에 얹는다 — 카드 높이를 같게 두기 위해서다.
/// - 품목명 SemiBold 13 한 줄 말줄임 · 세부정보(ⓘ, 흰 볼록 원 24)
/// - 면 요약 한 줄(넘치면 앞 / 뒤 두 줄). 업체명은 두지 않는다.
/// 고르면 파란 테두리 2.
final class CandidateCell: UICollectionViewCell {
    static let reuseID = "CandidateCell"

    private(set) var pillCode: String?
    var onInfoTap: (() -> Void)?
    // `크게 보기` 버튼 → 후보 이미지 비교 뷰어(NM-354). 사진을 누르면 카드 선택이다 — 뷰어를 열지 않는다.
    var onThumbnailTap: (() -> Void)?

    // 확대 트랜지션이 소스 프레임·이미지를 재려면 썸네일 뷰가 필요하다.
    var thumbnailView: UIImageView { thumb }

    private let surface = DSSurfaceView(spec: .glassListCard)
    private let thumbBox = UIView().then {
        $0.backgroundColor = DSColor.Neutral._100
        $0.layer.cornerRadius = DSRadius.md
        $0.clipsToBounds = true
    }
    private let thumb = UIImageView().then {
        $0.contentMode = .scaleAspectFit
    }
    private let zoomButton = GlassIconButton(icon: .openInFull)
    private let nameLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 13)
        $0.textColor = DSColor.textPrimary
        $0.lineBreakMode = .byTruncatingTail
    }
    // 허가 취소·취하(REVOKED) 품목에만 노출. 기본 숨김 — configure에서 결정.
    private let licenseBadge = LicenseRevokedBadge(compact: true).then { $0.isHidden = true }
    private let faceSummary = CandidateFaceSummaryView()
    /// 면 요약 자리 — 같은 줄 짝 카드가 두 줄이면 한 줄짜리도 같은 높이를 잡아 카드 높이를 맞춘다.
    private let faceSummaryBox = UIView()
    private var faceSummaryHeight: Constraint?
    private let info = UIControl()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        surface.frame = contentView.bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(surface)

        thumbBox.addSubview(thumb)
        thumb.snp.makeConstraints { $0.edges.equalToSuperview() }
        // 식약처 낱알 썸네일은 모두 256 × 140 — 카드 폭에 맞춰 같은 비율로 둔다.
        thumbBox.snp.makeConstraints { $0.height.equalTo(thumbBox.snp.width).multipliedBy(Self.thumbnailAspect) }
        thumbBox.addSubview(licenseBadge)
        licenseBadge.snp.makeConstraints { $0.top.leading.equalToSuperview().inset(5) }

        // `크게 보기`는 사진 칸 밖으로 누르는 영역(44)이 넘치므로 카드에 얹는다.
        zoomButton.accessibilityLabel = "크게 보기"
        zoomButton.addAction(UIAction { [weak self] _ in self?.onThumbnailTap?() }, for: .touchUpInside)

        // 세부정보 — 흰 볼록 원(24) 위에 ⓘ(16). 면이 아이콘을 덮지 않게 아이콘을 따로 얹는다.
        let infoSurface = DSSurfaceView(spec: .raisedNeutral(), cornerRadius: nil)
        infoSurface.isUserInteractionEnabled = false
        let infoIcon = UIImageView(image: DSIcon.info.uiImage).then {
            $0.tintColor = DSColor.Primary._500
            $0.contentMode = .scaleAspectFit
            $0.isUserInteractionEnabled = false
        }
        info.addSubview(infoSurface)
        info.addSubview(infoIcon)
        infoSurface.snp.makeConstraints { $0.edges.equalToSuperview() }
        infoIcon.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(16) }
        info.isAccessibilityElement = true
        info.accessibilityTraits = .button
        info.accessibilityLabel = "세부정보"
        info.addAction(UIAction { [weak self] _ in self?.onInfoTap?() }, for: .touchUpInside)
        info.snp.makeConstraints { $0.width.height.equalTo(24) }

        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let nameRow = UIStackView(arrangedSubviews: [nameLabel, info]).then {
            $0.axis = .horizontal
            $0.spacing = 4
            $0.alignment = .center
        }
        nameLabel.snp.makeConstraints { $0.height.equalTo(18) }

        faceSummaryBox.addSubview(faceSummary)
        faceSummary.snp.makeConstraints { $0.top.leading.equalToSuperview(); $0.trailing.lessThanOrEqualToSuperview() }
        faceSummaryBox.snp.makeConstraints { faceSummaryHeight = $0.height.equalTo(CandidateFaceSummaryView.lineHeight).constraint }

        let stack = UIStackView(arrangedSubviews: [thumbBox, nameRow, faceSummaryBox]).then {
            $0.axis = .vertical
            $0.spacing = 5
            $0.alignment = .fill
        }
        contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 7, left: 10, bottom: 8, right: 10)) }

        contentView.addSubview(zoomButton)
        zoomButton.snp.makeConstraints {
            $0.centerX.equalTo(thumbBox.snp.trailing).offset(-18)
            $0.centerY.equalTo(thumbBox.snp.top).offset(18)
        }
    }

    /// 식약처 낱알 썸네일 비율(세로 / 가로) — CDN 썸네일이 모두 256 × 140 이다(spec pillThumbnailUrl: 장변 256 · 종횡비 유지).
    static let thumbnailAspect: CGFloat = 140.0 / 256.0

    /// - Parameters:
    ///   - stacked: 이 카드의 면 요약이 카드 폭을 넘는다 — `앞` / `뒤` 두 줄로 내린다(각인은 자르지 않는다).
    ///   - rowStacked: 같은 줄 짝 카드 중 하나라도 두 줄 — 높이를 맞춘다.
    func configure(candidate: PillCandidateModel, selected: Bool, stacked: Bool, rowStacked: Bool) {
        pillCode = candidate.pillCode
        nameLabel.text = candidate.pillName ?? "이름 미상"
        licenseBadge.isHidden = candidate.licenseStatus != .revoked
        faceSummary.configure(front: candidate.front, back: candidate.back, stacked: stacked)
        faceSummaryHeight?.update(offset: rowStacked ? CandidateFaceSummaryView.stackedHeight : CandidateFaceSummaryView.lineHeight)

        // 서버 썸네일(pillThumbnailUrl, 장변 256px)을 Kingfisher로 로드 — 카드 사진 칸 크기로 다운샘플.
        thumb.kf.cancelDownloadTask()
        thumb.image = nil
        if let urlString = candidate.pillThumbnailUrl, let url = URL(string: urlString) {
            thumb.kf.setImage(
                with: url,
                options: [
                    .processor(DownsamplingImageProcessor(size: CGSize(width: 180, height: 180 * Self.thumbnailAspect))),
                    .scaleFactor(UIScreen.main.scale),
                    .cacheOriginalImage,
                    .transition(.fade(0.2)),
                ]
            )
        }
        setSelected(selected)
    }

    /// 고르면 파란 테두리 2.
    func setSelected(_ selected: Bool) {
        surface.spec = selected
            ? DSSurfaceSpec(
                fills: DSSurfaceSpec.glassListCard.fills,
                stroke: .solid(DSColor.Primary._500),
                strokeWidth: 2,
                shadows: DSSurfaceSpec.glassListCard.shadows
            )
            : .glassListCard
        accessibilityTraits = selected ? [.button, .selected] : .button
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumb.kf.cancelDownloadTask()
        thumb.image = nil
        onInfoTap = nil
        onThumbnailTap = nil
        pillCode = nil
        licenseBadge.isHidden = true
    }
}

// MARK: - 후보 면 요약 ("앞 [ALX3] (+) [마크] | 뒤 —")

/// 후보 카드 2줄의 면 요약 — 각인 · 구분선 · 마크를 같은 22pt 칸으로 늘어놓는다.
/// 마크는 마크 그림 제공 방식이 정해지기 전까지 **일반 마크 아이콘** 하나로 '있음'만 보인다.
/// 면에 아무것도 없으면 `—`.
final class CandidateFaceSummaryView: UIStackView {

    /// 칸 높이 18 — 한 줄 / 두 줄(앞 · 뒤, 사이 3).
    static let lineHeight: CGFloat = 18
    static let stackedHeight: CGFloat = 18 * 2 + 3

    init() {
        super.init(frame: .zero)
        axis = .horizontal
        spacing = 4
        alignment = .center
    }
    required init(coder: NSCoder) { fatalError() }

    /// - Parameter stacked: 카드 폭을 넘으면 `앞` / `뒤` 두 줄로 내린다 — 각인은 자르지 않는다(이 화면에서 가장 중요한 단서).
    func configure(front: PillFaceModel?, back: PillFaceModel?, stacked: Bool = false) {
        arrangedSubviews.forEach { $0.removeFromSuperview() }
        axis = stacked ? .vertical : .horizontal
        spacing = stacked ? 3 : 4
        alignment = stacked ? .leading : .center
        addArrangedSubview(faceGroup("앞", front))
        if !stacked {
            addArrangedSubview(UIView().then {
                $0.backgroundColor = DSColor.Neutral._300
                $0.snp.makeConstraints { $0.width.equalTo(1); $0.height.equalTo(12) }
            })
        }
        addArrangedSubview(faceGroup("뒤", back))
        accessibilityLabel = "앞면 \(Self.spoken(front)), 뒷면 \(Self.spoken(back))"
    }

    /// 한 줄로 그렸을 때의 폭 — 카드 안쪽 폭과 견줘 두 줄로 내릴지 정한다.
    static func singleLineWidth(front: PillFaceModel?, back: PillFaceModel?) -> CGFloat {
        let probe = CandidateFaceSummaryView()
        probe.configure(front: front, back: back, stacked: false)
        return probe.systemLayoutSizeFitting(
            CGSize(width: UIView.layoutFittingExpandedSize.width, height: lineHeight),
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .required
        ).width
    }

    private func faceGroup(_ title: String, _ face: PillFaceModel?) -> UIView {
        var items: [UIView] = [UILabel().then {
            $0.text = title
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 11)
            $0.textColor = DSColor.textTertiary
        }]
        if let imprint = face?.imprint, !imprint.isEmpty { items.append(imprintCell(imprint)) }
        if let line = face?.dividingLine, line != .unknown { items.append(dividingCell(line)) }
        if face?.hasMark == true { items.append(markCell(code: face?.markCode)) }
        if items.count == 1 {
            items.append(UILabel().then {
                $0.text = "—"
                $0.font = DSKitFontFamily.Pretendard.regular.font(size: 11)
                $0.textColor = DSColor.textTertiary
            })
        }
        return UIStackView(arrangedSubviews: items).then {
            $0.axis = .horizontal
            $0.spacing = 3
            $0.alignment = .center
        }
    }

    /// 흰 바탕 + 연한 테두리, r4, 높이 18.
    private func box() -> UIView {
        UIView().then {
            $0.backgroundColor = DSColor.surface
            $0.layer.cornerRadius = 4
            $0.layer.borderWidth = 1
            $0.layer.borderColor = DSColor.Neutral._200.cgColor
            $0.snp.makeConstraints { $0.height.equalTo(Self.lineHeight) }
        }
    }

    private func imprintCell(_ imprint: String) -> UIView {
        let cell = box()
        let label = UILabel().then {
            $0.attributedText = NSAttributedString(string: imprint, attributes: [
                .font: DSKitFontFamily.Pretendard.bold.font(size: 11),
                .foregroundColor: DSColor.textPrimary,
            ])
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        cell.addSubview(label)
        label.snp.makeConstraints { $0.centerY.equalToSuperview(); $0.leading.trailing.equalToSuperview().inset(4) }
        return cell
    }

    private func dividingCell(_ line: DividingLineModel) -> UIView {
        let cell = box()
        cell.snp.makeConstraints { $0.width.equalTo(Self.lineHeight) }
        let glyph = DividingLineGlyphView(line: line, tint: DSColor.Neutral._700)
        cell.addSubview(glyph)
        glyph.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(12) }
        return cell
    }

    /// 에셋 카탈로그 이미지 세트는 GIF 를 받지 않아 데이터 세트(`PillMarks/{markCode}`)로 담았다 — 한 번 풀면 캐시한다.
    private static let markImages = NSCache<NSString, UIImage>()

    private static func markImage(_ code: String) -> UIImage? {
        if let cached = markImages.object(forKey: code as NSString) { return cached }
        guard let data = NSDataAsset(name: "PillMarks/\(code)", bundle: .module)?.data,
              let image = UIImage(data: data) else { return nil }
        markImages.setObject(image, forKey: code as NSString)
        return image
    }

    /// 식약처 마크 그림 — 에셋 `PillMarks/{markCode}`(여백을 잘라 낸 흑백 GIF 150px, 같은 파일이 S3 assets/pill-marks).
    /// 앱에 없는 코드(데이터 갱신으로 새로 생긴 마크)는 일반 마크 아이콘으로 '있음'만 보인다.
    private func markCell(code: String?) -> UIView {
        let cell = box()
        cell.snp.makeConstraints { $0.width.equalTo(Self.lineHeight) }
        let icon: UIImageView
        if let code, let image = Self.markImage(code) {
            // 칸 안쪽 1pt 여백(spec 면 요약 칸).
            icon = UIImageView(image: image).then { $0.contentMode = .scaleAspectFit }
            icon.snp.makeConstraints { $0.width.height.equalTo(Self.lineHeight - 2) }
        } else {
            icon = UIImageView(image: UIImage(systemName: "seal",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
            icon.tintColor = DSColor.Neutral._700
        }
        cell.addSubview(icon)
        icon.snp.makeConstraints { $0.center.equalToSuperview() }
        return cell
    }

    private static func spoken(_ face: PillFaceModel?) -> String {
        var parts: [String] = []
        if let imprint = face?.imprint, !imprint.isEmpty { parts.append("각인 \(imprint)") }
        switch face?.dividingLine {
        case .plus?:  parts.append("십자 구분선")
        case .minus?: parts.append("일자 구분선")
        default:      break
        }
        if face?.hasMark == true { parts.append("마크 있음") }
        return parts.isEmpty ? "정보 없음" : parts.joined(separator: " ")
    }
}

// MARK: - 허가 종료 배지

/// 허가 취소·취하(REVOKED) 품목 표시 배지 — 품목명 옆 (XGm3Z).
/// warning-50 배경 / warning-100 테두리 1px / warning-700 텍스트 10pt, radius 4, padding (2,6).
/// V2.1.0: 살구색 태그 — 배경 Caution50 · 글자 Caution700 Medium 11 · r8. 테두리 없음.
/// compact(후보 사진 위)는 여백 1 · 5, 기본(결과 · 기록 행)은 3 · 8.
final class LicenseRevokedBadge: UIView {
    init(compact: Bool = false) {
        super.init(frame: .zero)
        backgroundColor = DSColor.Caution._50
        layer.cornerRadius = DSRadius.sm

        let label = UILabel().then {
            $0.text = "허가 종료"
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 11)
            $0.textColor = DSColor.Caution._700
        }
        addSubview(label)
        label.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(compact ? 1 : 3)
            $0.leading.trailing.equalToSuperview().inset(compact ? 5 : 8)
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

    // 조회 중 — 문구 없이 스피너만(spec NM-529). 보여 줄 목록이 없는 첫 조회에만 뜬다.
    private let spinner = UIActivityIndicatorView(style: .large).then {
        $0.color = DSColor.Primary._500
        $0.accessibilityLabel = "후보를 찾고 있어요"
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(spinner)
        spinner.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(40)
            $0.centerX.equalToSuperview()
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow != nil { spinner.startAnimating() } else { spinner.stopAnimating() }
    }
}

// MARK: - 입력 전 셀

/// 입력 전 — 속성 토큰도 조건도 없어 조회하지 않았다(수동 추가 · 추출 실패, DESIGN.pen ⑧-h · spec NM-529).
final class CandidateIdleCell: UICollectionViewCell {
    static let reuseID = "CandidateIdleCell"

    override init(frame: CGRect) {
        super.init(frame: frame)
        let circle = UIView().then {
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = 28
        }
        circle.snp.makeConstraints { $0.width.height.equalTo(56) }
        let icon = UIImageView(image: DSIcon.search.uiImage).then {
            $0.tintColor = DSColor.textTertiary
            $0.contentMode = .scaleAspectFit
        }
        circle.addSubview(icon)
        icon.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(26) }
        let text = UILabel().then {
            $0.text = "속성·각인을 입력하면 후보가 나타나요"
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 13)
            $0.textColor = DSColor.textTertiary
            $0.textAlignment = .center
            $0.numberOfLines = 0
        }
        contentView.addSubview(circle)
        contentView.addSubview(text)
        circle.snp.makeConstraints {
            $0.top.equalToSuperview().offset(24)
            $0.centerX.equalToSuperview()
        }
        text.snp.makeConstraints {
            $0.top.equalTo(circle.snp.bottom).offset(10)
            $0.centerX.equalToSuperview()
            $0.width.lessThanOrEqualTo(240)
            $0.bottom.equalToSuperview().inset(24)
        }
    }
    required init?(coder: NSCoder) { fatalError() }
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

// MARK: - 후보 섹션 헤더 ("후보 N개")

final class CandidateHeaderView: UICollectionReusableView {
    static let reuseID = "CandidateHeaderView"

    private let title = UILabel().then {
        $0.text = "후보"
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 15)
        $0.textColor = DSColor.textPrimary
    }

    /// `후보 N개` · 서버가 200개에서 자르면 `후보 200개+`. 조회 중 · 실패는 개수 없이 `후보`.
    func configure(count: Int?, truncated: Bool) {
        guard let count else { title.text = "후보"; return }
        title.text = "후보 \(count)개" + (truncated ? "+" : "")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let row = UIStackView(arrangedSubviews: [title, UIView()]).then {
            $0.axis = .horizontal; $0.alignment = .center
        }
        addSubview(row)
        row.snp.makeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.bottom.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(2)
        }
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - 후보 섹션 푸터 (목록 끝 한 줄)

/// 목록 끝 한 줄 — 둘 중 하나만 보인다.
/// - 이어서 조회(21번째부터) 실패: `불러오지 못했어요` · `다시 시도`. 보이는 후보는 그대로(spec NM-529)
/// - 서버가 200개에서 자른 목록: `찾는 약이 없다면 조건을 더 입력해 주세요`
final class CandidateListFooter: UICollectionReusableView {
    static let reuseID = "CandidateListFooter"

    enum Mode { case none, truncated, loadMoreFailed }

    var onRetry: (() -> Void)?

    private let label = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
        $0.textColor = DSColor.textTertiary
        $0.textAlignment = .center
    }
    private let retry = UIButton(configuration: .retryText(
        color: DSColor.Primary._600,
        size: 13,
        insets: NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
    ))
    private lazy var row = UIStackView(arrangedSubviews: [label, retry]).then {
        $0.axis = .horizontal
        $0.spacing = 4
        $0.alignment = .center
    }

    /// 숨길 때도 목록 아래 여백(24)은 남긴다.
    private lazy var collapse = heightAnchor.constraint(equalToConstant: 24)

    override init(frame: CGRect) {
        super.init(frame: frame)
        retry.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .touchUpInside)
        addSubview(row)
        row.snp.makeConstraints {
            $0.top.equalToSuperview().offset(14 + 4)
            $0.centerX.equalToSuperview()
            $0.leading.greaterThanOrEqualToSuperview()
            // 접을 때(높이 24) 이 제약이 양보한다.
            $0.bottom.equalToSuperview().inset(4 + 24).priority(.high)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(_ mode: Mode) {
        switch mode {
        case .none:
            row.isHidden = true
        case .truncated:
            row.isHidden = false
            label.text = "찾는 약이 없다면 조건을 더 입력해 주세요"
            retry.isHidden = true
        case .loadMoreFailed:
            row.isHidden = false
            label.text = "불러오지 못했어요"
            retry.isHidden = false
        }
        collapse.isActive = mode == .none
    }
}

/// 후보 조회 실패(DESIGN.pen 후보 조회 실패 · spec NM-529) — 부제는 인식 실패 · 세부정보 실패와 같은 정본 문구.
/// 다시 시도 = 지금 조건으로 재조회, 식별 횟수를 쓰지 않는다.
final class CandidateFailedCell: UICollectionViewCell {
    static let reuseID = "CandidateFailedCell"

    var onRetry: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let circle = UIView().then {
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = 32
        }
        circle.snp.makeConstraints { $0.width.height.equalTo(64) }
        let icon = UIImageView(image: DSIcon.alertCircle.uiImage).then {
            $0.tintColor = DSColor.textTertiary
            $0.contentMode = .scaleAspectFit
        }
        circle.addSubview(icon)
        icon.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(30) }

        let title = UILabel().then {
            $0.text = "후보를 불러오지 못했어요"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 16)
            $0.textColor = DSColor.textPrimary
            $0.textAlignment = .center
        }
        let desc = UILabel().then {
            $0.text = "네트워크 연결을 확인하고\n다시 시도해 주세요"
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
            $0.textColor = DSColor.textTertiary
            $0.textAlignment = .center
            $0.numberOfLines = 0
        }
        let retry = UIButton(configuration: .retryText(
            color: DSColor.textPrimary,
            size: 15,
            insets: NSDirectionalEdgeInsets(top: 11, leading: 20, bottom: 11, trailing: 20)
        )).then {
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = 12
            $0.layer.borderWidth = 1
            $0.layer.borderColor = DSColor.Neutral._200.cgColor
            $0.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .touchUpInside)
        }
        let texts = UIStackView(arrangedSubviews: [title, desc]).then {
            $0.axis = .vertical
            $0.spacing = 6
            $0.alignment = .center
        }
        let stack = UIStackView(arrangedSubviews: [circle, texts, retry]).then {
            $0.axis = .vertical
            $0.spacing = 14
            $0.alignment = .center
        }
        contentView.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(24)
            $0.leading.trailing.equalToSuperview()
        }
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - 다시 시도 버튼

private extension UIButton.Configuration {
    /// 글자만 있는 `다시 시도` 버튼 — Pretendard SemiBold.
    static func retryText(color: UIColor, size: CGFloat, insets: NSDirectionalEdgeInsets) -> UIButton.Configuration {
        var config = UIButton.Configuration.plain()
        config.title = "다시 시도"
        config.baseForegroundColor = color
        config.contentInsets = insets
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var attributes = $0
            attributes.font = DSKitFontFamily.Pretendard.semiBold.font(size: size)
            return attributes
        }
        return config
    }
}
