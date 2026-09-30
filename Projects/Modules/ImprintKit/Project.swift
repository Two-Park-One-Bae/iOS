import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

// 각인 OCR (NM-459). 모델은 ML 레포 models/imprint/20260907-crnn-ep60-s1 — models.lock 으로 받는다.
let project = Project.makeModule(
    name: "ImprintKit",
    targets: [.dynamicFramework, .unitTest],
    scripts: [.checkCoreMLModels],
    // **Debug 에서도 최적화한다.** 전처리(회전·CLAHE·리사이즈)가 화소 단위 루프라 -Onone 이면
    // 수십 배 느려진다(각인 PoC 실측 36~70배) — 개발 빌드에서 판독 한 번에 수십 초가 걸린다.
    frameworkSettings: ["SWIFT_OPTIMIZATION_LEVEL": "-O"]
)
