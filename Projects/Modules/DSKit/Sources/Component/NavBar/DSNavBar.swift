import UIKit

// MARK: - Nav Bar
// 높이 56, 배경 BgApp, 좌측 뒤로가기 버튼 56x56(chevron-left 아이콘 26), 중앙 제목 SemiBold 17, 우측 56x56 spacer

public final class DSNavBar: UIView {

    // MARK: - UI
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = DSKitFontFamily.Pretendard.semiBold.font(size: 17)
        label.textColor = DSColor.textPrimary
        label.textAlignment = .center
        return label
    }()

    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(DSIcon.chevronLeft.uiImage, for: .normal)
        button.tintColor = DSColor.textPrimary
        // chevron은 좌측에 붙이고 넓힌 터치 영역은 오른쪽으로만 — 좌측 여백이 커지지 않게.
        button.contentHorizontalAlignment = .leading
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 56),
            button.heightAnchor.constraint(equalToConstant: 56)
        ])
        return button
    }()

    private let spacer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 56),
            view.heightAnchor.constraint(equalToConstant: 56)
        ])
        return view
    }()
    
    // 부모 뷰에 추가될 때 leading/trailing을 자동으로 꽉 채움
    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard let superview else { return }
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: superview.leadingAnchor),
            trailingAnchor.constraint(equalTo: superview.trailingAnchor)
        ])
    }
    
    // MARK: - Dismiss Button Event
    public var onBackTapped: (() -> Void)?
    
    @objc private func backTapped() {
        onBackTapped?()
    }

    // MARK: - Init
    public init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        setupUI()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    private func setupUI() {
        backgroundColor = DSColor.bgApp

        let stack = UIStackView(arrangedSubviews: [backButton, titleLabel, spacer])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 56),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
    }

    
}

// MARK: - Methods

extension DSNavBar {

    public func setTitle(_ title: String) {
        titleLabel.text = title
    }

    public func setBackButtonHidden(_ hidden: Bool) {
        backButton.isHidden = hidden
        spacer.isHidden = hidden
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DSNavBar") {
    DSNavBar(title: "제목")
}
#endif
