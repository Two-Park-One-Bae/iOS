import UIKit
import SnapKit
import Then
import DSKit

final class AnalysisFailedVC: UIViewController {

    // MARK: - Callbacks

    var onRetry: (() -> Void)?
    var onBack: (() -> Void)?
    var onBackTapped: (() -> Void)?

    /// [임시 진단] 실제 실패 원인(에러 설명)을 화면에 노출 — 원인 확인 후 제거
    var detailMessage: String?

    // MARK: - UI

    private let navBar = DSNavBar(title: "").then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let iconBackground = UIView().then {
        $0.backgroundColor = DSColor.Error._50
        $0.layer.cornerRadius = 48
    }

    private let iconView = UIImageView().then {
        let config = UIImage.SymbolConfiguration(pointSize: 34, weight: .medium)
        $0.image = UIImage(systemName: "wifi.slash", withConfiguration: config)
        $0.tintColor = DSColor.Error._500
        $0.contentMode = .scaleAspectFit
    }

    private let titleLabel = UILabel().then {
        $0.text = "분석에 실패했어요"
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 20)
        $0.textColor = DSColor.textPrimary
        $0.textAlignment = .center
    }

    private let descLabel = UILabel().then {
        $0.text = "네트워크 연결을 확인하고\n다시 시도해 주세요"
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 15)
        $0.textColor = DSColor.textSecondary
        $0.textAlignment = .center
        $0.numberOfLines = 0
    }

    private let retryButton = PrimaryButton(title: "다시 시도")
    private let backButton = SecondaryButton(title: "뒤로")

    // MARK: - Init

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        setUI()
        setLayout()
        setActions()
        // [임시 진단] TestFlight 등 로그를 못 보는 빌드에서 실제 원인을 화면에 표시
        if let detailMessage, !detailMessage.isEmpty {
            descLabel.text = "네트워크 연결을 확인하고 다시 시도해 주세요\n\n[원인] \(detailMessage)"
        }
    }

    // MARK: - Setup

    private func setUI() {
        view.backgroundColor = DSColor.bgApp
        navBar.onBackTapped = { [weak self] in self?.onBackTapped?() }
    }

    private func setLayout() {
        view.addSubview(navBar)
        navBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
        }

        iconBackground.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(42)
        }

        let textStack = UIStackView(arrangedSubviews: [titleLabel, descLabel]).then {
            $0.axis = .vertical
            $0.spacing = 8
            $0.alignment = .center
        }

        let centerStack = UIStackView(arrangedSubviews: [iconBackground, textStack]).then {
            $0.axis = .vertical
            $0.spacing = 24
            $0.alignment = .center
        }

        view.addSubview(centerStack)
        iconBackground.snp.makeConstraints { $0.size.equalTo(96) }
        centerStack.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(40)
        }

        let footerStack = UIStackView(arrangedSubviews: [retryButton, backButton]).then {
            $0.axis = .vertical
            $0.spacing = 10
            $0.alignment = .fill
        }

        view.addSubview(footerStack)
        footerStack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-28)
        }
    }

    private func setActions() {
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func retryTapped() {
        onRetry?()
    }

    @objc private func backTapped() {
        onBack?()
    }
}
