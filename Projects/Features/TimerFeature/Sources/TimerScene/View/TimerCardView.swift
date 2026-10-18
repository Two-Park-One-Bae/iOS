import UIKit
import SnapKit
import Then
import DSKit
import Domain

// C1 타이머 카드 (RUNNING/PAUSED) — 링 + 라벨/태그/전체시간 + ✕,
// 메모 행, [일시정지|재개] [+1분] [메모]. 메모 인라인 입력(JNVXy) 포함.
// V2.1.0(NM-591): 유리 카드, ✕ · 액션 버튼은 흰 볼록. (+1분은 spec 대로 둔다 — 디자인 시안에는 빠져 있다.)
final class TimerCardView: UIView, UITextFieldDelegate {

    // MARK: - Callbacks

    var onPauseOrResume: (() -> Void)?
    var onExtend: (() -> Void)?
    var onStop: (() -> Void)?
    var onMemoSave: ((String) -> Void)?

    let timerID: UUID

    // MARK: - UI

    private let ring = TimerProgressRingView()
    private let labelLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 16)
        $0.textColor = DSColor.textPrimary
    }
    private let tagContainer = UIView().then { $0.layer.cornerRadius = 6 }
    private let tagLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.medium.font(size: 11)
    }
    private let totalLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
        $0.textColor = DSColor.textTertiary
    }
    // 정지 — 흰 볼록 원 30 · ✕ 15 Neutral500
    private let stopButton = TimerRaisedCircleButton(icon: .xMark, iconSize: 15, tint: DSColor.Neutral._500)

    private let memoLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
        $0.textColor = DSColor.textSecondary
        $0.isHidden = true
    }

    // 메모 인라인 입력 (JNVXy)
    private let memoInputRow = UIStackView().then {
        $0.axis = .horizontal
        $0.spacing = 8
        $0.alignment = .center
        $0.isHidden = true
    }
    private let memoFieldBox = UIView().then {
        $0.backgroundColor = DSColor.surface
        $0.layer.cornerRadius = DSRadius.md
        $0.layer.borderWidth = 1.5
        $0.layer.borderColor = DSColor.Primary._500.cgColor
    }
    private let memoField = UITextField().then {
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
        $0.textColor = DSColor.textPrimary
        $0.returnKeyType = .done
    }
    private let memoSaveButton = UIButton(type: .system).then {
        $0.backgroundColor = DSColor.Primary._500
        $0.layer.cornerRadius = 15
        $0.setImage(DSIcon.check.uiImage(size: 16), for: .normal)
        $0.tintColor = DSColor.Neutral._0
    }

    private let pauseResumeButton = TimerActionButton()
    private let extendButton = TimerActionButton()
    private let memoButton = TimerActionButton()

    // MARK: - Init

    init(timerID: UUID) {
        self.timerID = timerID
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        let surface = DSSurfaceView(spec: .glassCard)
        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(surface)

        // Top Row
        tagContainer.addSubview(tagLabel)
        tagLabel.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(3)
            $0.leading.trailing.equalToSuperview().inset(8)
        }
        let labelRow = UIStackView(arrangedSubviews: [labelLabel, tagContainer, UIView()]).then {
            $0.axis = .horizontal; $0.spacing = 8; $0.alignment = .center
        }
        let info = UIStackView(arrangedSubviews: [labelRow, totalLabel]).then {
            $0.axis = .vertical; $0.spacing = 6; $0.alignment = .leading
        }
        stopButton.snp.makeConstraints { $0.width.height.equalTo(30) }
        ring.snp.makeConstraints { $0.width.height.equalTo(64) }
        let topRow = UIStackView(arrangedSubviews: [ring, info, stopButton]).then {
            $0.axis = .horizontal; $0.spacing = 14; $0.alignment = .center
        }
        info.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Memo input row
        memoFieldBox.addSubview(memoField)
        memoField.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(9)
            $0.leading.trailing.equalToSuperview().inset(12)
        }
        memoSaveButton.snp.makeConstraints { $0.width.height.equalTo(30) }
        memoInputRow.addArrangedSubview(memoFieldBox)
        memoInputRow.addArrangedSubview(memoSaveButton)

        // Actions
        let actions = UIStackView(arrangedSubviews: [pauseResumeButton, extendButton, memoButton]).then {
            $0.axis = .horizontal; $0.spacing = 8; $0.distribution = .fillEqually
        }
        extendButton.configure(icon: nil, title: "+1분", style: .normal)
        memoButton.configure(icon: DSIcon.stickyNote.uiImage, title: "메모", style: .normal)

        let stack = UIStackView(arrangedSubviews: [topRow, memoLabel, memoInputRow, actions]).then {
            $0.axis = .vertical; $0.spacing = 12
        }
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(16) }

        stopButton.addAction(UIAction { [weak self] _ in self?.onStop?() }, for: .touchUpInside)
        pauseResumeButton.addAction(UIAction { [weak self] _ in self?.onPauseOrResume?() }, for: .touchUpInside)
        extendButton.addAction(UIAction { [weak self] _ in self?.onExtend?() }, for: .touchUpInside)
        memoButton.addAction(UIAction { [weak self] _ in self?.toggleMemoInput() }, for: .touchUpInside)
        memoSaveButton.addAction(UIAction { [weak self] _ in self?.saveMemo() }, for: .touchUpInside)
        memoField.delegate = self
    }

    // MARK: - Render

    func render(_ timer: TreatmentTimerModel) {
        let remaining = timer.remainingSeconds()
        let isPaused = timer.state == .paused
        labelLabel.text = timer.label
        tagLabel.text = timer.category.displayName
        tagLabel.textColor = timer.category.tagText
        tagContainer.backgroundColor = timer.category.tagBackground
        totalLabel.text = TimerFormat.duration(timer.duration)
        ring.update(
            remainingText: TimerFormat.countdown(remaining),
            progress: timer.duration > 0 ? CGFloat(remaining) / CGFloat(timer.duration) : 0,
            isPaused: isPaused
        )
        if isPaused {
            pauseResumeButton.configure(icon: DSIcon.play.uiImage, title: "재개", style: .resume)
        } else {
            pauseResumeButton.configure(icon: DSIcon.pause.uiImage, title: "일시정지", style: .normal)
        }
        if memoInputRow.isHidden {
            memoLabel.text = timer.memo
            memoLabel.isHidden = timer.memo == nil
        }
    }

    // MARK: - Memo Inline

    private func toggleMemoInput() {
        let opening = memoInputRow.isHidden
        memoInputRow.isHidden = !opening
        memoLabel.isHidden = opening || memoLabel.text == nil
        if opening {
            memoField.text = memoLabel.text
            memoField.becomeFirstResponder()
        } else {
            memoField.resignFirstResponder()
        }
    }

    private func saveMemo() {
        let text = memoField.text ?? ""
        memoInputRow.isHidden = true
        memoField.resignFirstResponder()
        memoLabel.text = text.isEmpty ? nil : text
        memoLabel.isHidden = text.isEmpty
        onMemoSave?(text) // 전부 지우고 저장 = 메모 삭제 (spec)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        saveMemo()
        return true
    }
}

// MARK: - 카드 하단 액션 버튼

final class TimerActionButton: UIControl {

    enum Style { case normal, resume }

    private let iconView = UIImageView().then {
        $0.contentMode = .scaleAspectFit
        $0.isHidden = true
    }
    private let titleLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 13)
    }

    // 흰 볼록(raisedNeutral, r12). 재개는 글자 · 아이콘만 Primary700.
    private let surface = DSSurfaceView(spec: .raisedNeutral(), cornerRadius: DSRadius.md)

    init() {
        super.init(frame: .zero)
        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        surface.isUserInteractionEnabled = false
        addSubview(surface)
        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel]).then {
            $0.axis = .horizontal; $0.spacing = 6; $0.alignment = .center
            $0.isUserInteractionEnabled = false
        }
        iconView.snp.makeConstraints { $0.width.height.equalTo(14) }
        addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(9)
            $0.centerX.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(icon: UIImage?, title: String, style: Style) {
        iconView.image = icon?.withRenderingMode(.alwaysTemplate)
        iconView.isHidden = icon == nil
        titleLabel.text = title
        switch style {
        case .normal:
            iconView.tintColor = DSColor.textSecondary
            titleLabel.textColor = DSColor.textPrimary
        case .resume:
            iconView.tintColor = DSColor.Primary._700
            titleLabel.textColor = DSColor.Primary._700
        }
    }

    override var isHighlighted: Bool {
        didSet { surface.alpha = isHighlighted ? 0.85 : 1 }
    }
}

// MARK: - 흰 볼록 원 버튼

/// 카드 우상단 ✕ 같은 작은 원 버튼 — 흰 볼록 면 위에 아이콘을 얹는다(면이 아이콘을 덮지 않게).
final class TimerRaisedCircleButton: UIControl {

    private let surface = DSSurfaceView(spec: .raisedNeutral(), cornerRadius: nil)

    init(icon: DSIcon, iconSize: CGFloat, tint: UIColor) {
        super.init(frame: .zero)
        surface.isUserInteractionEnabled = false
        addSubview(surface)
        surface.snp.makeConstraints { $0.edges.equalToSuperview() }
        let iconView = UIImageView(image: icon.uiImage).then {
            $0.tintColor = tint
            $0.contentMode = .scaleAspectFit
            $0.isUserInteractionEnabled = false
        }
        addSubview(iconView)
        iconView.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(iconSize) }
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { surface.alpha = isHighlighted ? 0.85 : 1 }
    }

    // 30 원이지만 누르는 영역은 44.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -7, dy: -7).contains(point)
    }
}
