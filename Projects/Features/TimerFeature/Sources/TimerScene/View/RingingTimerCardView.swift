import UIKit
import SnapKit
import Then
import DSKit
import Domain

// C1 만료(RINGING) 카드 — warning 배경, 맨 위 정렬.
// bell + 라벨 + 태그 + 00:00, 안내문, [+5분] [완료].
final class RingingTimerCardView: UIView {

    var onSnooze: (() -> Void)?
    var onComplete: (() -> Void)?

    let timerID: UUID

    private let descLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
        $0.textColor = DSColor.Warning._700
    }

    init(timer: TreatmentTimerModel) {
        self.timerID = timer.id
        super.init(frame: .zero)
        setup(timer: timer)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(timer: TreatmentTimerModel) {
        backgroundColor = DSColor.Warning._50
        layer.cornerRadius = 20
        layer.borderWidth = 1.5
        layer.borderColor = DSColor.Warning._300.cgColor

        // Top Row
        let bell = UIImageView().then {
            $0.image = UIImage(systemName: "bell.and.waves.left.and.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
            $0.tintColor = DSColor.Warning._600
            $0.contentMode = .scaleAspectFit
        }
        bell.snp.makeConstraints { $0.width.height.equalTo(20) }

        let label = UILabel().then {
            $0.text = timer.label
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 16)
            $0.textColor = DSColor.Warning._900
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
            $0.textColor = DSColor.Warning._600
        }
        let topRow = UIStackView(arrangedSubviews: [left, UIView(), time]).then {
            $0.axis = .horizontal; $0.alignment = .center
        }

        descLabel.text = "\(TimerFormat.duration(timer.duration)) 타이머가 종료되었습니다"

        // Buttons
        let snooze = UIControl().then {
            $0.backgroundColor = DSColor.Neutral._0
            $0.layer.cornerRadius = 12
            $0.layer.borderWidth = 1
            $0.layer.borderColor = DSColor.Warning._300.cgColor
        }
        let snoozeLabel = UILabel().then {
            $0.text = "+5분"
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 15)
            $0.textColor = DSColor.Warning._700
            $0.isUserInteractionEnabled = false
        }
        snooze.addSubview(snoozeLabel)
        snoozeLabel.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(11)
            $0.centerX.equalToSuperview()
        }

        let complete = UIControl().then {
            $0.backgroundColor = DSColor.Warning._600
            $0.layer.cornerRadius = 12
        }
        let check = UIImageView(image: DSIcon.check.uiImage).then {
            $0.tintColor = DSColor.Neutral._0
            $0.contentMode = .scaleAspectFit
        }
        check.snp.makeConstraints { $0.width.height.equalTo(16) }
        let completeLabel = UILabel().then {
            $0.text = "완료"
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 15)
            $0.textColor = DSColor.Neutral._0
        }
        let completeStack = UIStackView(arrangedSubviews: [check, completeLabel]).then {
            $0.axis = .horizontal; $0.spacing = 6; $0.alignment = .center
            $0.isUserInteractionEnabled = false
        }
        complete.addSubview(completeStack)
        completeStack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(11)
            $0.centerX.equalToSuperview()
        }

        let buttons = UIStackView(arrangedSubviews: [snooze, complete]).then {
            $0.axis = .horizontal; $0.spacing = 8; $0.distribution = .fillEqually
        }

        let stack = UIStackView(arrangedSubviews: [topRow, descLabel, buttons]).then {
            $0.axis = .vertical; $0.spacing = 12
        }
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(16) }

        snooze.addAction(UIAction { [weak self] _ in self?.onSnooze?() }, for: .touchUpInside)
        complete.addAction(UIAction { [weak self] _ in self?.onComplete?() }, for: .touchUpInside)
    }
}
