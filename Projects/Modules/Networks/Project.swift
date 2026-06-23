import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

let project = Project.makeModule(
    name: "Networks",
    targets: [.staticFramework, .unitTest],
    externalDependencies: [
        .SPM.Alamofire,
        .SPM.Moya,
        .SPM.CombineMoya,
    ]
)
