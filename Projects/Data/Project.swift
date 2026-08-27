import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

let project = Project.makeModule(
    name: "Data",
    targets: [.staticFramework, .unitTest],
    internalDependencies: [
        Dep.Domain.Domain,
        Dep.Modules.Networks.Networks,
        // 소셜 공급자 구현이 FirebaseAuthService 를 통해 Firebase 로그인을 수행한다 (NM-410)
        Dep.Core.Core,
    ],
    externalDependencies: [
        // GoogleSignIn 은 여기서 링크하지 않는다 — Core 가 단독으로 들고 있고(중복 링크 크래시 방지),
        // 구글 로그인은 Core 의 GoogleSignInService 를 통해 쓴다.
        // 카카오는 Firebase 비네이티브 — 액세스 토큰을 받아 서버에서 Custom Token 으로 교환한다.
        .SPM.KakaoSDKCommon,
        .SPM.KakaoSDKAuth,
        .SPM.KakaoSDKUser,
    ]
)
