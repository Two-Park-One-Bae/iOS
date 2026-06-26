import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

let project = Project.makeModule(
    name: "DSKit",
    targets: [.dynamicFramework],
    internalDependencies: [Dep.Core.Core],
    hasResources: true
)
