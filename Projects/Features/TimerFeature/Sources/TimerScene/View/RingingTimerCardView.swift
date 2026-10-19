import UIKit
import SnapKit
import Then
import DSKit
import Domain

// C1 만료(RINGING) 카드 — V2.1.0 살구색 카드(cautionCard), 맨 위 정렬.
// bell + 라벨 + 태그 + 00:00, 안내문, [완료](살구색 볼록 — 이 카드에서 하나뿐인 동작).
final class RingingTimerCardView: UIView {

    var onComplete: (() -> Void)?

    let timerID: UUID

    private let descLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
        $0.textColor = DSColor.Caution._700
    }

    init(timer: TreatmentTimerModel) {
        self.timerID = timer.id
        super.init(frame: .zero)
        setup(timer: timer)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(timer: TreatmentTimerModel) {
        let surface = DSSurfaceView(spec: .cautionCard)
        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(surface)

        // Top Row
        let bell = UIImageView().then {
            $0.image = DSIcon.bellRing.uiImage
            $0.tintColor = DSColor.Caution._600
            $0.contentMode = .scaleAspectFit
        }
        bell.snp.makeConstraints { $0.width.height.equalTo(20) }

        let label = UILabel().then {
            $0.text = timer.label
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 16)
            $0.textColor = DSColor.Caution._700
        }
        let tag = UIView().then {
            $0.backgroundColor = DSColor.Neutral._0
            $0.layer.cornerRadius = 6
        }
        let tagLabel = UILabel().then {
            $0.text = timer.category.displayName
            $0.font = DSKitFontFamily.Pretendard.medium.font(size: 11)
            $0.textColor = timer.category.tagText
        }
        tag.addSubview(tagLabel)
        tagLabel.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(3)
            $0.leading.trailing.equalToSuperview().inset(8)
        }
        let left = UIStackView(arrangedSubviews: [bell, label, tag]).then {
            $0.axis = .horizontal; $0.spacing = 8; $0.alignment = .center
        }
        let time = UILabel().then {
            $0.text = "00:00"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 16)
            $0.textColor = DSColor.Caution._600
        }
        let topRow = UIStackView(arrangedSubviews: [left, UIView(), time]).then {
            $0.axis = .horizontal; $0.alignment = .center
        }

        descLabel.text = "\(TimerFormat.duration(timer.duration)) 타이머가 종료되었습니다"

        // Button — [완료] (Button Caution)
        let complete = CautionButton(title: "완료").setIcon(.check)
        complete.changeInset(top: 11, leading: 24, bottom: 11, trailing: 24)

        let stack = UIStackView(arrangedSubviews: [topRow, descLabel, complete]).then {
            $0.axis = .vertical; $0.spacing = 12
        }
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(16) }

        complete.addAction(UIAction { [weak self] _ in self?.onComplete?() }, for: .touchUpInside)
    }
}
