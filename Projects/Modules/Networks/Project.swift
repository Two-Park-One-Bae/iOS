import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

let project = Project.makeModule(
    name: "Networks",
    targets: [.staticFramework, .unitTest],
    internalDependencies: [
        // APIRequestInterceptor 가 AppCheckService·FirebaseAuthService 참조 — Core는 내부 모듈 의존이 없어 순환 없음
        Dep.Core.Core,
    ],
    externalDependencies: [
        .SPM.Alamofire,
        .SPM.Moya,
        .SPM.CombineMoya,
    ]
)
