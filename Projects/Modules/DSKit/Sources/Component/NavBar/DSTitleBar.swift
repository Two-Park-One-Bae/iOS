import UIKit

// MARK: - Title Bar (뒤로가기 없는 네비바)
// DSNavBar 와 동일한 메트릭(높이 56, 배경 BgApp, 중앙 제목 SemiBold 17)이지만
// 좌측 뒤로 버튼이 없다. 제목 중앙 정렬 유지를 위해 양쪽에 26x26 spacer 배치.
// 뒤로가기가 부적절한 화면에서 사용.
//
// ⚠️ 현재 사용처 없음. 유일한 사용처였던 촬영 미리보기가 '뒤로 = 중단하고 홈으로'로 바뀌면서
// DSNavBar 로 돌아갔다(NM-341). 같은 요구가 다시 생길 수 있어 남겨둔다.

public final class DSTitleBar: UIView {

    // MARK: - UI

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = DSKitFontFamily.Pretendard.semiBold.font(size: 17)
        label.textColor = DSColor.textPrimary
        label.textAlignment = .center
        return label
    }()

    private func makeSpacer() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 26),
            view.heightAnchor.constraint(equalToConstant: 26)
        ])
        return view
    }

    // 부모 뷰에 추가될 때 leading/trailing을 자동으로 꽉 채움 (DSNavBar 동일)
    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard let superview else { return }
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: superview.leadingAnchor),
            trailingAnchor.constraint(equalTo: superview.trailingAnchor)
        ])
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

        let stack = UIStackView(arrangedSubviews: [makeSpacer(), titleLabel, makeSpacer()])
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
    }
}

// MARK: - Methods

extension DSTitleBar {
    public func setTitle(_ title: String) {
        titleLabel.text = title
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DSTitleBar") {
    DSTitleBar(title: "미리보기")
}
#endif
