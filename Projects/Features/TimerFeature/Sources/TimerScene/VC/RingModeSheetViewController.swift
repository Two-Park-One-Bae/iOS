import UIKit
import SnapKit
import DSKit
import Core

// YbkNe — 타이머 첫 시작 시 울림 방식을 고르는 바텀시트.
// "이대로 시작하기" → 선택 저장 후 onConfirm(선택 방식) 콜백.
public final class RingModeSheetViewController: UIViewController {

    public var onConfirm: ((RingMode) -> Void)?

    private let selector = RingModeSelectorView(selected: RingModeStore.shared.current)

    public init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.custom { _ in 430 }]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
    }

    public required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DSColor.surface
        setLayout()
    }

    private func setLayout() {
        // 벨 아이콘 원형
        let iconWrap = UIView()
        iconWrap.backgroundColor = DSColor.Primary._50
        iconWrap.layer.cornerRadius = 32
        iconWrap.snp.makeConstraints { $0.width.height.equalTo(64) }
        let bell = UIImageView(image: UIImage(systemName: "bell.badge.fill"))
        bell.tintColor = DSColor.Primary._600
        bell.contentMode = .scaleAspectFit
        iconWrap.addSubview(bell)
        bell.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(30) }

        let title = UILabel()
        title.text = "알람을 어떻게 알릴까요?"
        title.font = DSKitFontFamily.Pretendard.bold.font(size: 18)
        title.textColor = DSColor.textPrimary
        title.textAlignment = .center

        let body = UILabel()
        body.text = "타이머가 끝날 때 알리는 방식이에요.\n설정에서 언제든 바꿀 수 있어요."
        body.font = DSKitFontFamily.Pretendard.regular.font(size: 14)
        body.textColor = DSColor.textSecondary
        body.textAlignment = .center
        body.numberOfLines = 0

        let note = UILabel()
        note.text = "‘무음’은 벨소리가 켜져있으면 진동, 꺼져있으면 무음이에요."
        note.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
        note.textColor = DSColor.textTertiary
        note.textAlignment = .center
        note.numberOfLines = 0

        let button = PrimaryButton(title: "이대로 시작하기")
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let mode = self.selector.selectedMode
            RingModeStore.shared.current = mode
            self.dismiss(animated: true) { self.onConfirm?(mode) }
        }, for: .touchUpInside)

        let texts = UIStackView(arrangedSubviews: [title, body])
        texts.axis = .vertical
        texts.spacing = 8
        texts.alignment = .center

        let stack = UIStackView(arrangedSubviews: [iconWrap, texts, selector, note, button])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.setCustomSpacing(16, after: texts)
        stack.setCustomSpacing(10, after: selector)

        view.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(20)
            $0.leading.trailing.equalToSuperview().inset(24)
        }
        selector.snp.makeConstraints { $0.width.equalTo(stack.snp.width) }
        note.snp.makeConstraints { $0.width.equalTo(stack.snp.width) }
        button.snp.makeConstraints { $0.width.equalTo(stack.snp.width) }
    }
}
