import UIKit
import SnapKit
import Then
import DSKit
import Domain

// C1 타이머 카드 (RUNNING/PAUSED) — 링 + 라벨/태그/전체시간 + ✕,
// 메모 행, [일시정지|재개] [+1분] [메모]. 메모 인라인 입력(JNVXy) 포함.
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
    private let stopButton = UIButton(type: .system).then {
        $0.backgroundColor = DSColor.Neutral._100
        $0.layer.cornerRadius = 15
        $0.setImage(DSIcon.xMark.uiImage, for: .normal)
        $0.tintColor = DSColor.textSecondary
    }

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
        $0.backgroundColor = DSColor.Neutral._0
        $0.layer.cornerRadius = 10
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
        $0.setImage(DSIcon.check.uiImage, for: .normal)
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
        backgroundColor = DSColor.Neutral._0
        layer.cornerRadius = 20
        layer.masksToBounds = false
        layer.shadowColor = DSColor.textPrimary.cgColor
        layer.shadowOpacity = 0.07
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 12

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
        memoButton.configure(icon: UIImage(systemName: "note.text"), title: "메모", style: .normal)

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
            pauseResumeButton.configure(icon: UIImage(systemName: "play.fill"), title: "재개", style: .resume)
        } else {
            pauseResumeButton.configure(icon: UIImage(systemName: "pause.fill"), title: "일시정지", style: .normal)
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

    init() {
        super.init(frame: .zero)
        layer.cornerRadius = 10
        layer.borderWidth = 1
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
            backgroundColor = DSColor.Neutral._50
            layer.borderColor = DSColor.Neutral._200.cgColor
            iconView.tintColor = DSColor.textSecondary
            titleLabel.textColor = DSColor.textPrimary
        case .resume:
            backgroundColor = DSColor.Primary._50
            layer.borderColor = DSColor.Primary._300.cgColor
            iconView.tintColor = DSColor.Primary._700
            titleLabel.textColor = DSColor.Primary._700
        }
    }
}
