import UIKit
import SnapKit
import Then
import DSKit

final class AnalysisFailedVC: UIViewController {

    // MARK: - Callbacks

    var onRetry: (() -> Void)?
    var onBack: (() -> Void)?
    /// 뒤로 = 홈 복귀. 이 화면들엔 잃을 작업이 없어 확인 팝업 없이 바로 나간다.
    var onBackTapped: (() -> Void)?

    // MARK: - UI

    private let navBar = DSNavBar(title: "").then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let iconBackground = UIView().then {
        $0.backgroundColor = DSColor.Error._50
        $0.layer.cornerRadius = 48
    }

    private let iconView = UIImageView().then {
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
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 15)
        $0.textColor = DSColor.textSecondary
        $0.textAlignment = .center
        $0.numberOfLines = 0
    }

    private let retryButton = PrimaryButton(title: "다시 시도")
    private let backButton = SecondaryButton(title: "뒤로")

    /// 서버가 준 사유. 없으면 네트워크 문제로 본다.
    private let message: String?

    // MARK: - Init

    /// - Parameter message: 실패 사유(`APIError.errorDescription`). `nil` 이면 네트워크 안내로 떨어진다.
    ///
    /// 예전엔 문구·아이콘이 "네트워크 연결을 확인하고" + wifi-off 로 **고정**이라, 서버가 준 사유가
    /// 화면까지 왔는데도 버려졌다. App Check 실패처럼 네트워크와 무관한 오류까지 "연결을 확인하라"고
    /// 안내해 사용자를 엉뚱한 곳으로 보냈다.
    init(message: String? = nil) {
        self.message = message
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
    }

    // MARK: - Setup

    private func setUI() {
        view.backgroundColor = DSColor.bgApp
        navBar.onBackTapped = { [weak self] in self?.onBackTapped?() }

        // 사유를 받았으면 그대로 보여 주고 아이콘도 일반 경고로 바꾼다.
        // wifi-off 는 "연결을 확인하라"는 뜻이라, 네트워크가 멀쩡한 오류에 붙으면 문구와 어긋난다.
        descLabel.text = message ?? "네트워크 연결을 확인하고\n다시 시도해 주세요"
        iconView.image = (message == nil ? DSIcon.wifiOff : DSIcon.alertTriangle).uiImage
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
