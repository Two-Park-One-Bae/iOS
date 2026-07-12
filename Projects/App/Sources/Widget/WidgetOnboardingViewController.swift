import UIKit

// 위젯 미설정("탭하여 설정") 탭 → 위젯 설정 방법 온보딩 (NM-302). 네이티브 UIKit.
final class WidgetOnboardingViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "사용 방법"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )

        let header = UIImageView(image: UIImage(systemName: "lock.rectangle.on.rectangle"))
        header.tintColor = .systemBlue
        header.contentMode = .center
        header.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)

        let titleLabel = UILabel()
        titleLabel.text = "잠금화면 위젯 설정"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textAlignment = .center

        let steps = UIStackView(arrangedSubviews: [
            makeStep(1, "plus.rectangle.on.rectangle", "위젯 추가",
                     "잠금화면 편집 → 위젯 영역에 ‘처치 타이머’ 를 추가하세요."),
            makeStep(2, "hand.tap", "위젯 누르기",
                     "위젯 편집화면에서 ‘탭하여 설정’ 위젯을 누르면 편집(설정) 화면이 열려요."),
            makeStep(3, "checklist", "프리셋 선택",
                     "목록에서 프리셋을 고르면 그 위젯에 표시됩니다. 위젯마다 다르게 지정할 수 있어요.")
        ])
        steps.axis = .vertical
        steps.spacing = 20

        let root = UIStackView(arrangedSubviews: [header, titleLabel, steps])
        root.axis = .vertical
        root.spacing = 24
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func makeStep(_ num: Int, _ icon: String, _ stepTitle: String, _ desc: String) -> UIView {
        let circle = UIView()
        circle.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        circle.layer.cornerRadius = 26
        circle.translatesAutoresizingMaskIntoConstraints = false
        circle.widthAnchor.constraint(equalToConstant: 52).isActive = true
        circle.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .systemBlue
        iconView.contentMode = .center
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: circle.centerYAnchor)
        ])

        let stepLabel = UILabel()
        stepLabel.text = "STEP \(num)"
        stepLabel.font = .systemFont(ofSize: 12, weight: .bold)
        stepLabel.textColor = .systemBlue

        let titleLabel = UILabel()
        titleLabel.text = stepTitle
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)

        let descLabel = UILabel()
        descLabel.text = desc
        descLabel.font = .systemFont(ofSize: 15)
        descLabel.textColor = .secondaryLabel
        descLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [stepLabel, titleLabel, descLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        let row = UIStackView(arrangedSubviews: [circle, textStack])
        row.axis = .horizontal
        row.spacing = 16
        row.alignment = .top
        return row
    }
}
