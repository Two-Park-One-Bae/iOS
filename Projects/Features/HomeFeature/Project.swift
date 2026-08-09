import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

let project = Project.makeModule(
    name: "HomeFeature",
    targets: [.staticFramework, .interface, .unitTest, .demo],
    internalDependencies: [
        Dep.Features.Home.Interface,
        Dep.Features.DrugIdentification.Interface,
        Dep.Features.Timer.Interface,
        // 홈 '알약 식별' 카드의 남은 횟수 표시·진입 게이트에 PillUseCase 사용 (NM-323)
        Dep.Domain.Domain,
        Dep.Core.Core,
        Dep.Modules.DSKit.DSKit,
        Dep.Features.Base.Base,
        .SPM.SnapKit,
        .SPM.Then,
    ],
    interfaceDependencies: [
        Dep.Features.Base.Base,
    ]
)
