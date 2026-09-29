import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

let project = Project.makeModule(
    name: "SegmentationKit",
    targets: [.dynamicFramework, .unitTest],
    // 모델(mlpackage)은 git 에 없고 `make models` 로 받는다 (NM-482).
    // 빠져 있으면 Sources 글로브가 조용히 비어 모델 없는 앱이 빌드된다 — 실행해야 드러나는
    // 사고(LFS 포인터가 번들됐던 때와 같은 부류)라 빌드에서 막는다.
    scripts: [
        .pre(
            script: """
            set -euo pipefail
            "${SRCROOT}/../../../Tools/models.sh" check
            """,
            name: "CoreML 모델 확인",
            basedOnDependencyAnalysis: false
        )
    ]
)
