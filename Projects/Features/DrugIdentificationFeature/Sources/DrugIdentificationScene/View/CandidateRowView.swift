import UIKit
import SnapKit
import Then
import DSKit
import Domain
import Kingfisher

// ⑧ 후보 리스트의 후보 1개 (라디오 + 앞/뒤 썸네일 + 이름 + 회사)
final class CandidateRowView: UIView {

    var onTap: (() -> Void)?
    var onInfoTap: (() -> Void)?

    let candidate: PillCandidateModel
    private var isSelected = false

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

    init(candidate: PillCandidateModel) {
        self.candidate = candidate
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = DSColor.Neutral._0
        layer.cornerRadius = 14
        layer.borderWidth = 1
        layer.borderColor = DSColor.Neutral._200.cgColor

        // Radio
        let radio = UIView()
        radio.addSubview(ring)
        ring.addSubview(dot)
        radio.snp.makeConstraints { $0.width.height.equalTo(20) }
        ring.snp.makeConstraints { $0.edges.equalToSuperview() }
        dot.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(10) }

        // Thumb — 서버 낱알 이미지(pillImageUrl)를 Kingfisher로 로드.
        // 작은 셀이라 표시 크기(72×38)로 다운샘플 → 풀사이즈 디코드 낭비·메모리 절감.
        let thumb = makeThumb()
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

        // Texts
        let name = UILabel().then {
            $0.text = candidate.pillName ?? "이름 미상"
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 14)
            $0.textColor = DSColor.textPrimary
        }
        let company = UILabel().then {
            $0.text = candidate.companyName ?? "-"
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
            $0.textColor = DSColor.textTertiary
        }
        let texts = UIStackView(arrangedSubviews: [name, company]).then {
            $0.axis = .vertical
            $0.spacing = 2
        }
        name.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // 세부정보 진입 (라디오 선택과 별개 — 버튼이 터치를 소비해 행 탭과 분리)
        let info = UIButton(type: .system)
        info.setImage(UIImage(systemName: "info.circle"), for: .normal)
        info.tintColor = DSColor.Primary._500
        info.addAction(UIAction { [weak self] _ in self?.onInfoTap?() }, for: .touchUpInside)
        info.snp.makeConstraints { $0.width.height.equalTo(24) }

        let row = UIStackView(arrangedSubviews: [radio, thumb, texts, info]).then {
            $0.axis = .horizontal
            $0.spacing = 12
            $0.alignment = .center
        }
        addSubview(row)
        row.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(10)
            $0.leading.trailing.equalToSuperview().inset(12)
        }

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    private func makeThumb() -> UIImageView {
        let v = UIImageView().then {
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = 8
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFill
        }
        v.snp.makeConstraints { $0.width.equalTo(72); $0.height.equalTo(38) }
        return v
    }

    @objc private func tapped() { onTap?() }

    func setSelected(_ selected: Bool) {
        isSelected = selected
        dot.isHidden = !selected
        ring.layer.borderColor = (selected ? DSColor.Primary._500 : DSColor.Neutral._400).cgColor
        layer.borderColor = (selected ? DSColor.Primary._500 : DSColor.Neutral._200).cgColor
        layer.borderWidth = selected ? 2 : 1
        backgroundColor = selected ? DSColor.Primary._50 : DSColor.Neutral._0
    }
}
