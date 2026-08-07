import UIKit
import SnapKit
import Then
import DSKit

/*
 iOS 26.1 미만 안내 화면 — 타이머 탭 대체.

 타이머는 26.1+ 전용이다. 그 미만에서 쓰던 방식(로컬 알림 + 백그라운드 오디오 우회)은
 무음 모드·앱 종료 상황에서 알람을 보장하지 못했다. 처치 시각을 놓치면 안 되는 기능이라
 "반쯤 동작하는 타이머"를 주는 대신 사용을 막고 이유를 설명한다.

 구성은 같은 탭의 빈 상태(TimerEmptyView)를 따른다 — 헤더 + 아이콘 원 + 제목/설명.
 업데이트 경로는 DSBanner(.info) 로 안내한다. 소프트웨어 업데이트 화면 딥링크
 (prefs:root=...)는 비공개 URL 스킴이라 심사에서 걸리므로 쓰지 않는다.
 */
final class TimerUnavailableVC: UIViewController {

    // MARK: - UI

    private let titleLabel = UILabel().then {
        $0.text = "타이머"
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 24)
        $0.textColor = DSColor.textPrimary
    }

    // 디자인 pKazN — lucide triangle-alert (DSIcon.alertTriangle).
    // 원 배경은 두지 않는다 — Neutral._100 이 bgApp 과 채널당 0.01 차이라 보이지 않았다.
    private let icon = UIImageView(image: DSIcon.alertTriangle.uiImage).then {
        $0.tintColor = DSColor.Primary._500
        $0.contentMode = .scaleAspectFit
    }

    private let headline = UILabel().then {
        $0.text = "iOS 26.1 이상에서 사용할 수 있어요"
        $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 17)
        $0.textColor = DSColor.textPrimary
        $0.textAlignment = .center
        $0.numberOfLines = 0
    }

    private let subtitle = UILabel().then {
        $0.text = "처치 시각을 놓치지 않으려면 무음 모드와 잠금\n상태에서도 확실히 울리는 시스템 알람이 필요해요"
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
        $0.textColor = DSColor.textSecondary
        $0.textAlignment = .center
        $0.numberOfLines = 0
    }

    private let pathBanner = DSBanner(
        message: "설정 → 일반 → 소프트웨어 업데이트",
        style: .info
    )

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = DSColor.bgApp
        setLayout()
    }

    // MARK: - Layout

    private func setLayout() {
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            $0.leading.trailing.equalToSuperview().inset(20)
        }

        icon.snp.makeConstraints {
            $0.width.equalTo(56)
            $0.height.equalTo(51)   // 에셋 비율 유지 (56:51)
        }

        let texts = UIStackView(arrangedSubviews: [headline, subtitle]).then {
            $0.axis = .vertical
            $0.spacing = 8
            $0.alignment = .center
        }

        let stack = UIStackView(arrangedSubviews: [icon, texts, pathBanner]).then {
            $0.axis = .vertical
            $0.spacing = 20
            $0.alignment = .center
        }
        view.addSubview(stack)
        stack.snp.makeConstraints {
            $0.center.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview().inset(32)
        }
    }
}
