import UIKit

/*
 SplashViewController (NM-359)

 앱 콜드런치 직후 잠깐 보이는 브랜드 화면 — 흰 배경에 로고(앱 아이콘) 하나만 가운데 두는 미니멀 스타일.
 AppCoordinator가 첫 화면으로 띄우고, 표시가 끝나면 onFinish 콜백으로 탭바 전환을 위임한다
 (스플래시 자신은 다음 화면을 모른다).
 */
final class SplashViewController: UIViewController {

    /// 스플래시 표시가 끝나 다음 화면으로 넘어갈 시점을 알린다.
    var onFinish: (() -> Void)?

    /// 로고 등장 후 유지 시간. 이후 onFinish 호출.
    private let holdDuration: TimeInterval = 0.8

    private let logoView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "SplashLogo"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        view.addSubview(logoView)
        NSLayoutConstraint.activate([
            logoView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            logoView.widthAnchor.constraint(equalToConstant: 140)   // 디자인 기준 (DESIGN.pen · mLokq)
        ])

        logoView.alpha = 0   // 등장 전
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.35) { self.logoView.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) { [weak self] in
            self?.onFinish?()
        }
    }
}
