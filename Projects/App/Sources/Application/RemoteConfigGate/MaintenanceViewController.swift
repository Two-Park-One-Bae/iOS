import UIKit

// 점검 모드(maintenance_mode=true) 시 앱 전체를 덮는 차단 화면.
// 안내 문구는 Remote Config(maintenance_message)에서 내려온 값을 사용한다.
final class MaintenanceViewController: UIViewController {

    private let message: String

    init(message: String) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true   // 스와이프로 닫기 방지
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let icon = UIImageView(image: UIImage(systemName: "wrench.and.screwdriver.fill"))
        icon.tintColor = .systemGray
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = .init(pointSize: 52, weight: .regular)

        let titleLabel = UILabel()
        titleLabel.text = "서비스 점검 중이에요"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.text = message.isEmpty
            ? "더 나은 서비스를 위해 점검 중입니다.\n잠시 후 다시 이용해주세요."
            : message
        messageLabel.font = .systemFont(ofSize: 16, weight: .regular)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, messageLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.setCustomSpacing(24, after: icon)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }
}
