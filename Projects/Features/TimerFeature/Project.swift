import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

let project = Project.makeModule(
    name: "TimerFeature",
    // 알람 계층만 도입하는 PR — UI(.demo)·테스트(.unitTest)는 NM-264에서 함께 추가한다.
    targets: [.staticFramework, .interface],
    internalDependencies: [
        Dep.Features.Timer.Interface,
        Dep.Core.Core,
        Dep.Domain.Domain,
        Dep.Data.Data,
        Dep.Modules.DSKit.DSKit,
        Dep.Modules.TimerShared.TimerShared,
        Dep.Features.Base.Base,
        .SPM.SnapKit,
        .SPM.Then,
    ],
    interfaceDependencies: [
        Dep.Features.Base.Base,
    ]
)
