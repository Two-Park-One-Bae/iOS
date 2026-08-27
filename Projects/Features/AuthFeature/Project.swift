import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

let project = Project.makeModule(
    name: "AuthFeature",
    targets: [.staticFramework, .interface, .unitTest],
    internalDependencies: [
        Dep.Features.Auth.Interface,
        // 로그인·동의·탈퇴 전부 AuthUseCase 를 통한다. 소셜 SDK 는 Data 뒤에 있어 여기서 보이지 않는다.
        Dep.Domain.Domain,
        Dep.Core.Core,
        Dep.Modules.DSKit.DSKit,
        Dep.Features.Base.Base,
        .SPM.SnapKit,
        .SPM.Then,
    ],
    interfaceDependencies: [
        Dep.Features.Base.Base,
        Dep.Domain.Domain,
    ]
)
