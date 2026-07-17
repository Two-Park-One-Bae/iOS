import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

let project = Project.makeModule(
    name: "DrugIdentificationFeature",
    targets: [.staticFramework, .interface, .unitTest, .demo],
    internalDependencies: [
        Dep.Features.DrugIdentification.Interface,
        Dep.Core.Core,
        Dep.Domain.Domain,
        Dep.Data.Data,
        Dep.Modules.DSKit.DSKit,
        Dep.Modules.Networks.Networks,
        Dep.Modules.SegmentationKit.SegmentationKit,
        Dep.Features.Base.Base,
        .SPM.SnapKit,
        .SPM.Then,
        .SPM.Kingfisher,
    ],
    interfaceDependencies: [
        Dep.Features.Base.Base,
    ]
)
