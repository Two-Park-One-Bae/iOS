import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

let project = Project.makeModule(
    name: "SegmentationKit",
    targets: [.dynamicFramework, .unitTest]
)
