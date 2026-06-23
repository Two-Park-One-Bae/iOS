import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "Domain",
    targets: [.dynamicFramework, .unitTest]
)
