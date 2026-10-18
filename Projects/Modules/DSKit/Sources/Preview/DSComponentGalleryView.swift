#if DEBUG
import UIKit

/// V2.1.0 공용 컴포넌트 갤러리 — DESIGN.pen `Foundation / Components · V2.1.0` 시트와 나란히 놓고 Xcode Preview로 비교한다.
/// 유리 재질은 흰 바탕에선 티가 안 나서 앱 바탕(bgApp) 위에 올린다.
private func makeComponentGallery() -> UIView {
    func section(_ title: String, _ views: [UIView], axis: NSLayoutConstraint.Axis = .vertical) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = DSKitFontFamily.Pretendard.semiBold.font(size: 12)
        label.textColor = DSColor.textTertiary

        let body = UIStackView(arrangedSubviews: views)
        body.axis = axis
        body.spacing = 12
        body.alignment = axis == .vertical ? .fill : .center

        let stack = UIStackView(arrangedSubviews: [label, body])
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }

    func surface(_ spec: DSSurfaceSpec, _ radius: CGFloat? = DSRadius.card) -> UIView {
        let view = DSSurfaceView(spec: spec, cornerRadius: radius)
        view.heightAnchor.constraint(equalToConstant: 64).isActive = true
        return view
    }

    let disabled = PrimaryButton(title: "비활성").setEnabled(false)
    let error = DSTextField(label: "라벨", placeholder: "입력하세요")
    error.text = "AST"
    error.setError(true)

    let content = UIStackView(arrangedSubviews: [
        section("Surface", [
            surface(.glassCard), surface(.glassListCard), surface(.glassFloating, nil),
            surface(.glassCardSelected), surface(.cautionCard), surface(.successListCard)
        ]),
        section("Button", [
            PrimaryButton(title: "버튼"), SecondaryButton(title: "버튼"), disabled,
            CautionButton(title: "완료").setIcon(.check), DestructiveButton(title: "삭제"), TextButton(title: "텍스트 버튼")
        ]),
        section("Icon Button · Floating", [IconButton(icon: .xMark), GlassIconButton(), FloatingButton()], axis: .horizontal),
        section("Chip · Tag", [
            DSDropdownChip(text: "전체"), DSDropdownChip(text: "입력", isConfirmed: true), DSChip(text: "표시용"), DSTag(text: "처치")
        ], axis: .horizontal),
        section("Text Field", [DSTextField(label: "라벨", placeholder: "입력하세요"), error]),
        section("Card · List Row", [
            {
                let card = DSCard(title: "카드 제목", body: "카드 본문 내용이 들어갑니다.")
                card.setActions([SecondaryButton(title: "취소"), PrimaryButton(title: "확인")])
                return card
            }(),
            DSListRow(style: .compact, icon: .history, title: "항목 제목", subtitle: "보조 설명")
        ]),
        section("Banner", [DSBanner(message: "안내 메시지가 여기에 표시됩니다.")]),
        section("Menu", [
            DSMenuView(items: [
                .init(icon: .pencil, title: "수정") {},
                .init(icon: .trash, title: "삭제", isDestructive: true) {}
            ])
        ], axis: .horizontal),
        section("Modal", [
            DSConfirmDialogView(title: "이 프리셋을 삭제할까요?", message: nil, confirmTitle: "삭제", confirmStyle: .destructive)
        ], axis: .horizontal),
        section("Bottom Bar", [
            DSBottomBar(buttons: [SecondaryButton(title: "공유"), PrimaryButton(title: "완료")], disclaimer: "식별 결과는 참고용 보조 정보입니다.")
        ])
    ])
    content.axis = .vertical
    content.spacing = 28
    content.translatesAutoresizingMaskIntoConstraints = false

    let scroll = UIScrollView()
    scroll.backgroundColor = DSColor.bgApp
    scroll.addSubview(content)
    NSLayoutConstraint.activate([
        content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
        content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
        content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
        content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20)
    ])
    return scroll
}

// 뷰 컨트롤러로 띄워야 화면 폭을 다 쓴다 — 뷰를 바로 넘기면 스크롤 뷰가 최소 폭으로 줄어든다.
#Preview("V2.1.0 Components") {
    let viewController = UIViewController()
    let gallery = makeComponentGallery()
    gallery.frame = viewController.view.bounds
    gallery.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    viewController.view.addSubview(gallery)
    return viewController
}
#endif
