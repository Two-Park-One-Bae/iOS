import ProjectDescription
import EnvPlugin
import DependencyPlugin
import ConfigPlugin

public extension Project {
    static func makeModule(
        name: String,
        targets: Set<FeatureTarget> = [.staticFramework, .unitTest],
        internalDependencies: [TargetDependency] = [],
        externalDependencies: [TargetDependency] = [],
        interfaceDependencies: [TargetDependency] = [],
        hasResources: Bool = false
    ) -> Project {
        var projectTargets: [Target] = []
        let bundleId = "\(Environment.bundlePrefix).\(name.lowercased())"
        let allDependencies = internalDependencies + externalDependencies

        if targets.contains(.staticFramework) || targets.contains(.dynamicFramework) {
            let product: Product = targets.contains(.dynamicFramework) ? .framework : .staticFramework
            projectTargets.append(
                .target(
                    name: name,
                    destinations: .iOS,
                    product: product,
                    bundleId: bundleId,
                    deploymentTargets: Environment.deploymentTarget,
                    sources: ["Sources/**"],
                    resources: hasResources ? ["Resources/**"] : nil,
                    dependencies: allDependencies
                )
            )
        }

        if targets.contains(.interface) {
            projectTargets.append(
                .target(
                    name: "\(name)Interface",
                    destinations: .iOS,
                    product: .staticFramework,
                    bundleId: "\(bundleId).interface",
                    deploymentTargets: Environment.deploymentTarget,
                    sources: ["Interface/Sources/**"],
                    dependencies: interfaceDependencies
                )
            )
        }

        if targets.contains(.unitTest) {
            projectTargets.append(
                .target(
                    name: "\(name)Tests",
                    destinations: .iOS,
                    product: .unitTests,
                    bundleId: "\(bundleId).tests",
                    deploymentTargets: Environment.deploymentTarget,
                    sources: ["Tests/Sources/**"],
                    dependencies: [.target(name: name)]
                )
            )
        }

        if targets.contains(.demo) {
            projectTargets.append(
                .target(
                    name: "\(name)Demo",
                    destinations: .iOS,
                    product: .app,
                    bundleId: "\(bundleId).demo",
                    deploymentTargets: Environment.deploymentTarget,
                    infoPlist: .default,
                    sources: ["Demo/Sources/**"],
                    dependencies: [.target(name: name)]
                )
            )
        }

        return Project(
            name: name,
            settings: .settings(configurations: XCConfig.framework),
            targets: projectTargets
        )
    }
}
