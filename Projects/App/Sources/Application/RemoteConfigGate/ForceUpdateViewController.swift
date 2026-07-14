import UIKit

// 강제 업데이트(현재 버전 < min_supported_version) 시 앱 전체를 덮는 차단 화면.
// "업데이트하기" → Remote Config(app_store_url) 로 이동. 미설정이면 App Store 앱만 연다.
final class ForceUpdateViewController: UIViewController {

    private let appStoreURL: URL?

    init(appStoreURL: URL?) {
        self.appStoreURL = appStoreURL
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let icon = UIImageView(image: UIImage(systemName: "arrow.up.circle.fill"))
        icon.tintColor = view.tintColor
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = .init(pointSize: 52, weight: .regular)

        let titleLabel = UILabel()
        titleLabel.text = "업데이트가 필요해요"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.text = "원활한 사용을 위해\n최신 버전으로 업데이트해주세요."
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

        var config = UIButton.Configuration.filled()
        config.title = "업데이트하기"
        config.cornerStyle = .large
        config.buttonSize = .large
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.openStore()
        })
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    private func openStore() {
        // app_store_url 이 설정돼 있으면 그 링크로, 아니면 App Store 앱을 연다.
        let url = appStoreURL ?? URL(string: "itms-apps://itunes.apple.com")
        guard let url, UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
