import ProjectDescription
import EnvPlugin
import ConfigPlugin

// 폰(iOS)·워치(watchOS) 공용 타이머 도메인.
// 두 플랫폼이 "같은 타입"을 링크해야 동기화 스냅샷 JSON(Codable)이 100% 일치한다.
// UIKit/Combine 없이 Foundation 만 의존 → 멀티플랫폼 안전.
let project = Project(
    name: "TimerDomain",
    settings: .settings(base: XCConfig.base, configurations: XCConfig.framework),
    targets: [
        .target(
            name: "TimerDomain",
            destinations: [.iPhone, .iPad, .appleWatch],
            product: .staticFramework,
            bundleId: "\(Environment.bundlePrefix).timerdomain",
            deploymentTargets: .multiplatform(iOS: "17.0", watchOS: "10.0"),
            sources: ["Sources/**"],
            settings: .settings(base: XCConfig.base)
        ),
    ]
)
