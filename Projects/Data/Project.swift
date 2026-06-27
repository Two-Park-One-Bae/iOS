import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

let project = Project.makeModule(
    name: "Data",
    targets: [.staticFramework, .unitTest],
    internalDependencies: [
        Dep.Domain.Domain,
        Dep.Modules.Networks.Networks,
    ]
)
