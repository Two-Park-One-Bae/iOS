import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

// 마크 유무·종·임베딩 (NM-512). 모델은 ML 레포 models/mark/20260925-convnext-species — models.lock 으로 받는다.
let project = Project.makeModule(
    name: "MarkKit",
    targets: [.dynamicFramework, .unitTest],
    // 전처리(OpenCV 재구현)를 각인과 같이 쓴다 — 두 모델이 같은 흑백·정사각·회전·CLAHE 를 지나야 한다.
    internalDependencies: [
        Dep.Modules.ImprintKit.ImprintKit,
    ],
    scripts: [.checkCoreMLModels],
    // **Debug 에서도 최적화한다.** 전처리(회전·CLAHE·리사이즈)가 화소 단위 루프라 -Onone 이면
    // 수십 배 느려진다(각인 PoC 실측 36~70배) — 개발 빌드에서 판독 한 번에 수십 초가 걸린다.
    frameworkSettings: ["SWIFT_OPTIMIZATION_LEVEL": "-O"]
)
