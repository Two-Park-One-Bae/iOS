import UIKit
import SnapKit
import Then
import DSKit

// ⑨ 결과 공유 바텀시트 — "텍스트 복사" / "PDF로 저장"을 아이콘·설명과 함께 분리 제시.
// 디자인시스템(DSKit)에 맞춘 카드형 시트. 아래에서 슬라이드 업, 딤 탭·닫기로 해제.
final class ShareActionSheetVC: UIViewController {

    private let onCopyText: () -> Void
    private let onSavePDF: () -> Void

    private let dimView = UIView()
    private let card = UIView()

    init(onCopyText: @escaping () -> Void, onSavePDF: @escaping () -> Void) {
        self.onCopyText = onCopyText
        self.onSavePDF = onSavePDF
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.9,
                       initialSpringVelocity: 0, options: [.curveEaseOut]) {
            self.card.transform = .identity
            self.dimView.alpha = 1
        }
    }

    private func setup() {
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        dimView.alpha = 0
        view.addSubview(dimView)
        dimView.snp.makeConstraints { $0.edges.equalToSuperview() }
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimTapped)))

        card.backgroundColor = DSColor.Neutral._0
        card.layer.cornerRadius = 24
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        card.transform = CGAffineTransform(translationX: 0, y: 600) // 화면 밖 아래 → viewDidAppear에서 슬라이드 업
        view.addSubview(card)
        card.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview().offset(40) // 하단 라운드가 화면 밖으로 살짝 넘어가 코너가 안 보이게
        }

        let grip = UIView().then {
            $0.backgroundColor = DSColor.Neutral._300
            $0.layer.cornerRadius = 2.5
        }
        let title = UILabel().then {
            $0.text = "공유하기"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 17)
            $0.textColor = DSColor.textPrimary
            $0.textAlignment = .center
        }

        let copyRow = makeOptionRow(
            icon: "doc.on.doc", title: "텍스트 복사", subtitle: "바로 붙여넣기 좋아요"
        ) { [weak self] in self?.close(then: self?.onCopyText) }

        let pdfRow = makeOptionRow(
            icon: "arrow.down.doc", title: "PDF로 저장", subtitle: "문서 파일로 저장·공유"
        ) { [weak self] in self?.close(then: self?.onSavePDF) }

        let closeButton = UIButton(type: .system).then {
            $0.setTitle("닫기", for: .normal)
            $0.setTitleColor(DSColor.textTertiary, for: .normal)
            $0.titleLabel?.font = DSKitFontFamily.Pretendard.semiBold.font(size: 15)
            $0.addAction(UIAction { [weak self] _ in self?.close(then: nil) }, for: .touchUpInside)
        }

        let stack = UIStackView(arrangedSubviews: [title, copyRow, pdfRow, closeButton]).then {
            $0.axis = .vertical
            $0.spacing = 10
            $0.setCustomSpacing(16, after: title)
            $0.setCustomSpacing(6, after: pdfRow)
        }
        card.addSubview(grip)
        card.addSubview(stack)
        grip.snp.makeConstraints {
            $0.top.equalToSuperview().offset(10)
            $0.centerX.equalToSuperview()
            $0.width.equalTo(40); $0.height.equalTo(5)
        }
        stack.snp.makeConstraints {
            $0.top.equalTo(grip.snp.bottom).offset(14)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(12).priority(.high)
            $0.bottom.lessThanOrEqualToSuperview().inset(40)
        }
    }

    private func makeOptionRow(
        icon: String, title: String, subtitle: String, action: @escaping () -> Void
    ) -> UIControl {
        let container = UIControl().then {
            $0.backgroundColor = DSColor.Neutral._100
            $0.layer.cornerRadius = 14
        }

        let iconWrap = UIView().then {
            $0.backgroundColor = DSColor.Primary._50
            $0.layer.cornerRadius = 22
        }
        let iconView = UIImageView().then {
            $0.image = UIImage(systemName: icon)
            $0.tintColor = DSColor.Primary._500
            $0.contentMode = .scaleAspectFit
            $0.preferredSymbolConfiguration = .init(pointSize: 18, weight: .semibold)
        }
        iconWrap.addSubview(iconView)
        iconWrap.snp.makeConstraints { $0.width.height.equalTo(44) }
        iconView.snp.makeConstraints { $0.center.equalToSuperview() }

        let titleLabel = UILabel().then {
            $0.text = title
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 15)
            $0.textColor = DSColor.textPrimary
        }
        let subtitleLabel = UILabel().then {
            $0.text = subtitle
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
            $0.textColor = DSColor.textTertiary
        }
        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel]).then {
            $0.axis = .vertical
            $0.spacing = 2
            $0.alignment = .leading
            $0.isUserInteractionEnabled = false
        }

        let chevron = UIImageView().then {
            $0.image = UIImage(systemName: "chevron.right")
            $0.tintColor = DSColor.Neutral._400
            $0.preferredSymbolConfiguration = .init(pointSize: 12, weight: .semibold)
        }

        let row = UIStackView(arrangedSubviews: [iconWrap, textStack, UIView(), chevron]).then {
            $0.axis = .horizontal
            $0.spacing = 14
            $0.alignment = .center
            $0.isUserInteractionEnabled = false
        }
        container.addSubview(row)
        row.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(12)
            $0.leading.trailing.equalToSuperview().inset(14)
        }

        container.addAction(UIAction { _ in action() }, for: .touchUpInside)
        container.addTarget(self, action: #selector(rowPressed(_:)), for: [.touchDown, .touchDragEnter])
        container.addTarget(self, action: #selector(rowReleased(_:)),
                            for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        return container
    }

    @objc private func rowPressed(_ sender: UIControl) {
        UIView.animate(withDuration: 0.1) { sender.backgroundColor = DSColor.Neutral._200 }
    }
    @objc private func rowReleased(_ sender: UIControl) {
        UIView.animate(withDuration: 0.1) { sender.backgroundColor = DSColor.Neutral._100 }
    }

    @objc private func dimTapped() { close(then: nil) }

    /// 시트를 아래로 내리고, 완전히 닫힌 뒤 액션 실행(다음 화면 present 충돌 방지).
    private func close(then action: (() -> Void)?) {
        UIView.animate(withDuration: 0.22, animations: {
            self.card.transform = CGAffineTransform(translationX: 0, y: 600)
            self.dimView.alpha = 0
        }, completion: { _ in
            self.dismiss(animated: false) { action?() }
        })
    }
}
