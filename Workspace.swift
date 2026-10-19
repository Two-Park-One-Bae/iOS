import ProjectDescription
import EnvPlugin

let workspace = Workspace(
    name: Environment.workspaceName,
    projects: [
        "Projects/**"
    ],
    additionalFiles: [
        "XCConfig/**"
    ],
    // 생성 프로젝트를 이 Xcode 버전에서 이미 점검한 것으로 표시한다 — 다시 생성할 때마다
    // 모든 모듈에 "Update to recommended settings" 경고가 뜨지 않게. Xcode 를 올리면 같이 올린다.
    generationOptions: .options(lastXcodeUpgradeCheck: "27.0.0")
)
