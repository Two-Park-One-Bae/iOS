import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

let project = Project.makeModule(
    name: "TabBarFeature",
    targets: [.staticFramework, .interface, .unitTest, .demo],
    internalDependencies: [
        Dep.Core.Core,
        Dep.Modules.DSKit.DSKit,
        Dep.Features.Base.Base,
        Dep.Features.Home.Interface,
        Dep.Features.Timer.Interface,
    ],
    interfaceDependencies: [
        Dep.Features.Base.Base,
    ]
)
