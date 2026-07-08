import UIKit
import SnapKit
import Then
import DSKit

// C1 카드 진행률 링 — 64pt, 트랙 Neutral100, 진행 Primary500(일시정지 Neutral300),
// 중앙 카운트다운 텍스트. 12시 방향에서 시계방향으로 남은 비율만큼 채운다.
final class TimerProgressRingView: UIView {

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()

    private let remainingLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 13)
        $0.textColor = DSColor.textPrimary
        $0.textAlignment = .center
    }

    override var intrinsicContentSize: CGSize { CGSize(width: 64, height: 64) }

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        [trackLayer, progressLayer].forEach {
            $0.fillColor = UIColor.clear.cgColor
            $0.lineWidth = 4.5
            $0.lineCap = .round
            layer.addSublayer($0)
        }
        trackLayer.strokeColor = DSColor.Neutral._100.cgColor

        addSubview(remainingLabel)
        remainingLabel.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 2.25
        let path = UIBezierPath(
            arcCenter: center, radius: radius,
            startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true
        ).cgPath
        trackLayer.path = path
        progressLayer.path = path
    }

    /// progress 0...1 (남은 비율), paused 시 회색 처리
    func update(remainingText: String, progress: CGFloat, isPaused: Bool) {
        remainingLabel.text = remainingText
        remainingLabel.font = DSKitFontFamily.Pretendard.bold.font(size: remainingText.count > 5 ? 11 : 13)
        remainingLabel.textColor = isPaused ? DSColor.textSecondary : DSColor.textPrimary
        progressLayer.strokeColor = (isPaused ? DSColor.Neutral._300 : DSColor.Primary._500).cgColor
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        progressLayer.strokeEnd = max(0, min(1, progress))
        CATransaction.commit()
    }
}
