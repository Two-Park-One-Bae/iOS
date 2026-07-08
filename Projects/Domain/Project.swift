import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

let project = Project.makeModule(
    name: "Domain",
    targets: [.dynamicFramework, .unitTest],
    internalDependencies: [
        // 폰·워치 공용 타이머 도메인 — Exports.swift 에서 @_exported 로 재노출
        Dep.Modules.TimerDomain.TimerDomain,
    ]
)
