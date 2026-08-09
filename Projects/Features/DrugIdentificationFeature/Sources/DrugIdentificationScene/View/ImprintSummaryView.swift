import UIKit
import SnapKit
import Then
import DSKit
import Domain

// 앞/뒤 표기값 그리드 (각인 · 구분선 · 마크 라벨 칩) — ⑧ 각인 Row / ⑤ 결과행 공용
final class ImprintSummaryView: UIView {

    private let frontRow = FaceRow(face: "앞")
    private let backRow = FaceRow(face: "뒤")

    init() {
        super.init(frame: .zero)
        let stack = UIStackView(arrangedSubviews: [frontRow, backRow]).then {
            $0.axis = .vertical
            $0.spacing = 5
        }
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(front: PillFaceModel?, back: PillFaceModel?) {
        frontRow.update(front)
        backRow.update(back)
    }

    // MARK: - Face Row

    private final class FaceRow: UIView {
        private let imprintChip = LabeledChip(label: "각인")
        private let dividerChip = LabeledChip(label: "구분선")
        private let markChip = LabeledChip(label: "마크")

        init(face: String) {
            super.init(frame: .zero)
            let faceLabel = UILabel().then {
                $0.text = face
                $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 11)
                $0.textColor = DSColor.textTertiary
            }
            faceLabel.snp.makeConstraints { $0.width.equalTo(16) }

            let cols = UIStackView(arrangedSubviews: [imprintChip, dividerChip, markChip]).then {
                $0.axis = .horizontal
                $0.spacing = 10
                $0.alignment = .center
            }
            let row = UIStackView(arrangedSubviews: [faceLabel, cols]).then {
                $0.axis = .horizontal
                $0.spacing = 8
                $0.alignment = .center
            }
            addSubview(row)
            row.snp.makeConstraints { $0.edges.equalToSuperview() }
        }
        required init?(coder: NSCoder) { fatalError() }

        func update(_ m: PillFaceModel?) {
            let imprint = m?.imprint?.isEmpty == false ? m!.imprint! : nil
            imprintChip.setValue(imprint ?? "없음", filled: imprint != nil)
            let div = m?.dividingLine?.displayName
            dividerChip.setValue(div ?? "없음", filled: div != nil)
            let mark = m?.hasMark == true
            markChip.setValue(mark ? "있음" : "없음", filled: mark)
        }
    }

    // MARK: - Labeled Chip

    private final class LabeledChip: UIView {
        private let valueLabel = UILabel()
        private let chip = UIView()

        init(label: String) {
            super.init(frame: .zero)
            let lb = UILabel().then {
                $0.text = label
                $0.font = DSKitFontFamily.Pretendard.medium.font(size: 11)
                $0.textColor = DSColor.textTertiary
            }
            chip.backgroundColor = DSColor.Neutral._100
            chip.layer.cornerRadius = 6
            valueLabel.font = DSKitFontFamily.Pretendard.bold.font(size: 12)
            chip.addSubview(valueLabel)
            valueLabel.snp.makeConstraints {
                $0.top.bottom.equalToSuperview().inset(1)
                $0.leading.trailing.equalToSuperview().inset(7)
            }
            let stack = UIStackView(arrangedSubviews: [lb, chip]).then {
                $0.axis = .horizontal
                $0.spacing = 4
                $0.alignment = .center
            }
            addSubview(stack)
            stack.snp.makeConstraints { $0.edges.equalToSuperview() }
        }
        required init?(coder: NSCoder) { fatalError() }

        func setValue(_ value: String, filled: Bool) {
            valueLabel.text = value
            valueLabel.textColor = filled ? DSColor.textPrimary : DSColor.textTertiary
        }
    }
}
