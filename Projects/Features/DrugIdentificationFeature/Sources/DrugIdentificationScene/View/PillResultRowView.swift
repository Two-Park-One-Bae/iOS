import UIKit
import SnapKit
import Then
import DSKit
import Domain
import Kingfisher

/// ⑤ 인식 결과 카드의 상태 (NM-513). 결과 화면은 알약별 **상태만** 보여 주고, 속성·조건은 수정 화면의 일이다.
enum PillResultState: Equatable {
    /// 선택 전 — 후보를 아직 고르지 않았다.
    case pending
    /// 인식 실패(EXTRACTION_FAILED) — 카드를 눌러 직접 입력한다.
    case failed
    /// 식별 완료 — 고른 후보.
    case identified(name: String, company: String?, isRevoked: Bool, isManual: Bool)

    /// 카드 배경·테두리·번호 색. 사진 위 영역 테두리와 번호 태그도 같은 색(`accent`)을 쓴다.
    var tone: PillResultTone {
        switch self {
        case .pending:
            return PillResultTone(background: DSColor.surface, border: nil,
                                  badgeFill: DSColor.Primary._50, badgeBorder: DSColor.Primary._100,
                                  badgeText: DSColor.Primary._600, accent: DSColor.Primary._500)
        case .failed:
            return PillResultTone(background: DSColor.Error._50, border: DSColor.Error._100,
                                  badgeFill: DSColor.Error._100, badgeBorder: nil,
                                  badgeText: DSColor.Error._700, accent: DSColor.Error._500)
        case .identified:
            return PillResultTone(background: DSColor.Success._50, border: DSColor.Success._100,
                                  badgeFill: DSColor.Success._100, badgeBorder: nil,
                                  badgeText: DSColor.Success._700, accent: DSColor.Success._500)
        }
    }
}

struct PillResultTone {
    let background: UIColor
    let border: UIColor?
    let badgeFill: UIColor
    let badgeBorder: UIColor?
    let badgeText: UIColor
    /// 사진 위 영역 테두리 · 번호 태그 — 카드와 번호로 짝을 짓는다.
    let accent: UIColor
}

// ⑤ 인식 결과 리스트의 알약 1개 — 한 줄 상태 카드 (DESIGN.pen NM-490 ⑤)
//
// 번호 · 잘라 낸 사진 · 상태 글자 · 더보기(⋮). 카드 전체가 누를 영역(= 수정), ⋮ = 수정 / 삭제.
final class PillResultRowView: UIView {

    var onTap: (() -> Void)?
    var onMenu: (() -> Void)?

    private let badge = UIView().then {
        $0.layer.cornerRadius = 13
    }
    private let badgeLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 13)
        $0.textAlignment = .center
    }
    // 크롭은 알약 둘레에 딱 맞게 잘려 있어 칸을 꽉 채우면 둥근 모서리에 가장자리가 먹힌다 — 안쪽으로 들여 전체를 보인다.
    private let thumbBox = UIView().then {
        $0.backgroundColor = DSColor.Neutral._100
        $0.layer.cornerRadius = 10
        $0.clipsToBounds = true
    }
    private let thumb = UIImageView().then {
        $0.contentMode = .scaleAspectFit
    }
    private let titleLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 14)
        $0.lineBreakMode = .byTruncatingTail
    }
    private let revokedBadge = LicenseRevokedBadge()
    private let subtitleLabel = UILabel().then {
        $0.lineBreakMode = .byTruncatingTail
    }
    private let menuButton = UIButton(type: .system).then {
        $0.setImage(DSIcon.moreVertical.uiImage, for: .normal)
        $0.tintColor = DSColor.textTertiary
        $0.accessibilityLabel = "더보기"   // 아이콘 이름("ic more vertical")이 그대로 읽히지 않게
    }

    init(number: Int, thumbnail: UIImage?, state: PillResultState) {
        super.init(frame: .zero)
        setup()
        thumb.image = thumbnail
        configure(number: number, state: state)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        layer.cornerRadius = 14
        layer.shadowColor = UIColor(red: 0x1E / 255, green: 0x29 / 255, blue: 0x3B / 255, alpha: 1).cgColor
        layer.shadowOpacity = 0.04
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 6

        badge.addSubview(badgeLabel)
        badgeLabel.snp.makeConstraints { $0.center.equalToSuperview() }
        badge.snp.makeConstraints { $0.width.height.equalTo(26) }
        thumbBox.addSubview(thumb)
        thumb.snp.makeConstraints { $0.edges.equalToSuperview().inset(4) }
        thumbBox.snp.makeConstraints { $0.width.height.equalTo(40) }
        menuButton.snp.makeConstraints { $0.width.height.equalTo(28) }
        menuButton.addAction(UIAction { [weak self] _ in self?.onMenu?() }, for: .touchUpInside)

        // 품목명은 줄이되 허가 종료 배지는 지킨다.
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        revokedBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        revokedBadge.setContentHuggingPriority(.required, for: .horizontal)
        let titleRow = UIStackView(arrangedSubviews: [titleLabel, revokedBadge, UIView()]).then {
            $0.axis = .horizontal
            $0.spacing = 6
            $0.alignment = .center
        }
        let texts = UIStackView(arrangedSubviews: [titleRow, subtitleLabel]).then {
            $0.axis = .vertical
            $0.spacing = 2
        }
        let row = UIStackView(arrangedSubviews: [badge, thumbBox, texts, menuButton]).then {
            $0.axis = .horizontal
            $0.spacing = 10
            $0.alignment = .center
        }
        addSubview(row)
        row.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.leading.equalToSuperview().inset(14)
            $0.trailing.equalToSuperview().inset(8)
        }
        snp.makeConstraints { $0.height.equalTo(64) }

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    @objc private func tapped() { onTap?() }

    /// 번호는 삭제·추가 때 다시 매기므로 상태와 함께 바꿀 수 있어야 한다.
    func configure(number: Int, state: PillResultState) {
        let tone = state.tone
        backgroundColor = tone.background
        layer.borderColor = tone.border?.cgColor
        layer.borderWidth = tone.border == nil ? 0 : 1

        badge.backgroundColor = tone.badgeFill
        badge.layer.borderColor = tone.badgeBorder?.cgColor
        badge.layer.borderWidth = tone.badgeBorder == nil ? 0 : 1
        badgeLabel.textColor = tone.badgeText
        badgeLabel.text = "\(number)"

        switch state {
        case .pending:
            titleLabel.text = "후보를 골라 주세요"
            titleLabel.textColor = DSColor.textSecondary
            revokedBadge.isHidden = true
            subtitleLabel.isHidden = true

        case .failed:
            titleLabel.text = "정보 인식 실패"
            titleLabel.textColor = DSColor.Error._700
            revokedBadge.isHidden = true
            subtitleLabel.isHidden = false
            subtitleLabel.text = "직접 입력"
            subtitleLabel.font = DSKitFontFamily.Pretendard.semiBold.font(size: 12)
            subtitleLabel.textColor = DSColor.textSecondary

        case let .identified(name, company, isRevoked, isManual):
            titleLabel.text = name
            titleLabel.textColor = DSColor.Success._900
            revokedBadge.isHidden = !isRevoked
            // 수동 추가는 업체 옆에 '직접 추가' — 사진에 대응 영역이 없는 알약이라는 표시.
            let parts = [company, isManual ? "직접 추가" : nil].compactMap { $0 }.filter { !$0.isEmpty }
            subtitleLabel.isHidden = parts.isEmpty
            subtitleLabel.text = parts.joined(separator: " · ")
            subtitleLabel.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
            subtitleLabel.textColor = DSColor.textTertiary
        }
    }

    /// 수동 추가 알약은 크롭이 없어 고른 후보의 낱알 썸네일을 쓴다. 없으면(CDN 404) 빈 칸 그대로.
    func setThumbnail(url: String?) {
        guard let url = url.flatMap(URL.init(string:)) else { return }
        thumb.kf.setImage(with: url, options: [
            .processor(DownsamplingImageProcessor(size: CGSize(width: 40, height: 40))),
            .scaleFactor(UIScreen.main.scale),
        ])
    }
}
