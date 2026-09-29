import ProjectDescription

public extension TargetScript {
    /// CoreML 모델(mlpackage)을 번들하는 모듈에 붙이는 빌드 전 검사 (NM-482).
    ///
    /// 모델은 git 에 없고 `make models` 로 받는다. 빠져 있으면 Sources 글로브가 조용히 비어
    /// 모델 없는 앱이 빌드된다 — 실행해야 드러나는 사고(LFS 포인터가 번들됐던 때와 같은 부류)라
    /// 빌드에서 막는다. 모듈은 `Projects/Modules/<이름>` 에 있어야 한다(저장소 루트 기준 세 단계 위).
    static let checkCoreMLModels: TargetScript = .pre(
        script: """
        set -euo pipefail
        "${SRCROOT}/../../../Tools/models.sh" check
        """,
        name: "CoreML 모델 확인",
        basedOnDependencyAnalysis: false
    )
}
