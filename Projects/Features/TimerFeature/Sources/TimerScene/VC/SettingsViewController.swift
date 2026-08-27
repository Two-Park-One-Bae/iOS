import UIKit
import SnapKit
import DSKit
import Core

// Xoc5z — 설정 · 타이머 섹션(NM-308) + 계정 섹션(NM-410).
//
// 계정 섹션의 실제 동작(로그아웃·탈퇴)은 여기서 하지 않는다. TimerFeature 가 인증을 알게 되면
// 타이머 화면이 Auth 계층에 묶이므로, 콜백만 노출하고 조립은 App 이 한다.
public final class SettingsViewController: UIViewController {

    private let selector = RingModeSelectorView(selected: RingModeStore.shared.current)

    /// 계정 행을 눌렀을 때. 확인 다이얼로그·실제 처리는 주입한 쪽 책임이다.
    public var onLogoutTapped: (() -> Void)?
    public var onDeleteAccountTapped: (() -> Void)?

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

        let note = UILabel()
        note.text = "‘소리’는 무음 모드에서도 크게 울려요.\n‘무음’은 벨소리가 켜져있으면 진동, 꺼져있으면 무음이에요."
        note.font = DSKitFontFamily.Pretendard.regular.font(size: 11)
        note.textColor = DSColor.textTertiary
        note.numberOfLines = 0

        let timerSection = makeSectionLabel("타이머")
        let accountSection = makeSectionLabel("계정")
        let card = makeRingModeCard()
        let logoutRow = makeLogoutRow()
        let deleteRow = makeDeleteAccountRow()

        let root = UIStackView(arrangedSubviews: [
            title, timerSection, card, note, accountSection, logoutRow, deleteRow,
        ])
        root.axis = .vertical
        root.spacing = 12
        root.setCustomSpacing(4, after: timerSection)
        root.setCustomSpacing(8, after: card)
        // 섹션 사이는 넉넉히 띄우고, 섹션 라벨과 첫 행은 붙인다 (디자인 Xoc5z).
        root.setCustomSpacing(24, after: note)
        root.setCustomSpacing(4, after: accountSection)

        view.addSubview(root)
        root.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
    }

    // MARK: - Sections

    private func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = DSKitFontFamily.Pretendard.semiBold.font(size: 13)
        label.textColor = DSColor.textSecondary
        return label
    }

    private func makeRingModeCard() -> UIView {
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
        return card
    }

    private func makeLogoutRow() -> UIView {
        let row = DSListRow(
            style: .compact,
            icon: .logOut,
            title: "로그아웃",
            subtitle: "언제든 다시 로그인할 수 있어요"
        )
        row.setIconBackground(DSColor.Primary._50)
        row.setIconTint(DSColor.Primary._500)
        row.onTap { [weak self] in self?.onLogoutTapped?() }
        return row
    }

    private func makeDeleteAccountRow() -> UIView {
        // 되돌릴 수 없는 액션이라 제목까지 Error 색으로 둔다 (디자인 Xoc5z).
        let row = DSListRow(style: .compact, icon: .userX, title: "계정 삭제", subtitle: "")
        row.setTitleColor(DSColor.Error._600)
        row.setIconBackground(DSColor.Error._50)
        row.setIconTint(DSColor.Error._600)
        row.onTap { [weak self] in self?.onDeleteAccountTapped?() }
        return row
    }
}
