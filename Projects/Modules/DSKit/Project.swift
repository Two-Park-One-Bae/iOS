import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "DSKit",
    targets: [.dynamicFramework],
    hasResources: true
)
