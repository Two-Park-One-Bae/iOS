import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

let project = Project.makeModule(
    name: "BaseFeatureDependency",
    targets: [.staticFramework],
    internalDependencies: [
        Dep.Modules.DSKit.DSKit,
        Dep.Core.Core,
    ]
)
