import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

// 각인 OCR (NM-459). 모델은 ML 레포 models/imprint/20260907-crnn-ep60-s1 — models.lock 으로 받는다.
let project = Project.makeModule(
    name: "ImprintKit",
    targets: [.dynamicFramework, .unitTest],
    scripts: [.checkCoreMLModels]
)
