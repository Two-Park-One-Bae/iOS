import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

// 마크 유무·종·임베딩 (NM-512). 모델은 ML 레포 models/mark/20260925-convnext-species — models.lock 으로 받는다.
let project = Project.makeModule(
    name: "MarkKit",
    targets: [.dynamicFramework, .unitTest],
    scripts: [.checkCoreMLModels]
)
