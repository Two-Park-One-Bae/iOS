import Observation

// MARK: - Deep Link

/// 교차 탭 진입점. 푸시알림 · 유니버설 링크 · 위젯 등에서 들어오는 목적지를 표현한다.
public enum DeepLink: Hashable {
    case itemDetail(itemID: String)
}

// MARK: - App Router

/// 메인(`.main`) 단계 내부의 네비게이션을 한 곳에서 소유한다.
/// - 탭 선택(`selectedTab`)
/// - 각 탭의 스택 라우터(`home` / `explore` / `settings`)
///
/// 앱 단계 전환(splash·onboarding·auth 등)은 `AppState`가 담당하며 여기서 다루지 않는다.
@Observable
public final class AppRouter {
    public var selectedTab: MainTab = .home

    public let home = HomeRouter()
    public let explore = ExploreRouter()
    public let settings = SettingsRouter()

    /// `.main` 진입 전에 도착한 링크 보관함(콜드스타트 대응).
    private var pendingLink: DeepLink?

    public init() {}

    // MARK: - Deep Link

    /// 교차 탭 이동의 유일한 진입점. 링크 → (탭 점프 + 스택 진입) 매핑을 여기에 모은다.
    public func handle(_ link: DeepLink) {
        switch link {
        case .itemDetail(let itemID):
            selectedTab = .home
            home.popToRoot()
            home.navigate(to: .detail(itemID: itemID))
        }
    }

    /// 아직 메인에 진입하지 않았을 때 링크를 보관한다.
    public func enqueue(_ link: DeepLink) {
        pendingLink = link
    }

    /// 메인 진입 시 호출 — 보류된 링크가 있으면 적용한다.
    public func flushPendingLink() {
        guard let link = pendingLink else { return }
        pendingLink = nil
        handle(link)
    }
}
