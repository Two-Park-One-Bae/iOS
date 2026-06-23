import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

let project = Project.makeModule(
    name: "HomeFeature",
    targets: [.staticFramework, .interface, .unitTest, .demo],
    internalDependencies: [
        Dep.Core.Core,
        Dep.Domain.Domain,
        Dep.Data.Data,
        Dep.Modules.DSKit.DSKit,
        Dep.Modules.Networks.Networks,
        Dep.Features.Base.Base,
    ],
    interfaceDependencies: [
        Dep.Features.Base.Base,
    ]
)
