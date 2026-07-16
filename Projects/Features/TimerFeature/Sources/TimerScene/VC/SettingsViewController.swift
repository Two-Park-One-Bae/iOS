import UIKit
import SnapKit
import DSKit
import Core

// Xoc5z — 설정 · 타이머 섹션 (NM-308). 현재는 울림 방식만.
public final class SettingsViewController: UIViewController {

    private let selector = RingModeSelectorView(selected: RingModeStore.shared.current)

    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = DSColor.bgApp
        setLayout()
        selector.onChange = { mode in RingModeStore.shared.current = mode }
    }

    private func setLayout() {
        let title = UILabel()
        title.text = "설정"
        title.font = DSKitFontFamily.Pretendard.bold.font(size: 28)
        title.textColor = DSColor.textPrimary

        let section = UILabel()
        section.text = "타이머"
        section.font = DSKitFontFamily.Pretendard.semiBold.font(size: 13)
        section.textColor = DSColor.textSecondary

        // 울림 방식 카드
        let cardTitle = UILabel()
        cardTitle.text = "울림 방식"
        cardTitle.font = DSKitFontFamily.Pretendard.bold.font(size: 15)
        cardTitle.textColor = DSColor.textPrimary

        let cardSubtitle = UILabel()
        cardSubtitle.text = "타이머가 끝날 때 알리는 방식"
        cardSubtitle.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
        cardSubtitle.textColor = DSColor.textSecondary

        let cardStack = UIStackView(arrangedSubviews: [cardTitle, cardSubtitle, selector])
        cardStack.axis = .vertical
        cardStack.spacing = 6
        cardStack.setCustomSpacing(12, after: cardSubtitle)
        cardStack.isLayoutMarginsRelativeArrangement = true
        cardStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        let card = UIView()
        card.backgroundColor = DSColor.surface
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 1
        card.layer.borderColor = DSColor.border.cgColor
        card.addSubview(cardStack)
        cardStack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let note = UILabel()
        note.text = "‘소리’는 무음 모드에서도 크게 울려요.\n‘무음’은 벨소리가 켜져있으면 진동, 꺼져있으면 무음이에요."
        note.font = DSKitFontFamily.Pretendard.regular.font(size: 11)
        note.textColor = DSColor.textTertiary
        note.numberOfLines = 0

        let root = UIStackView(arrangedSubviews: [title, section, card, note])
        root.axis = .vertical
        root.spacing = 12
        root.setCustomSpacing(4, after: section)
        root.setCustomSpacing(8, after: card)
        view.addSubview(root)
        root.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
    }
}
