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
