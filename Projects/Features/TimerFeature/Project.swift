import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

let project = Project.makeModule(
    name: "TimerFeature",
    targets: [.staticFramework, .interface, .unitTest, .demo],
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
