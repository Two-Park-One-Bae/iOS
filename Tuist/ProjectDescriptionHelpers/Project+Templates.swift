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
        hasResources: Bool = false,
        // 모듈별로 추가할 커스텀 타깃·스킴 (예: 버전별 데모 앱 + 위젯 익스텐션).
        extraTargets: [Target] = [],
        extraSchemes: [Scheme] = []
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
                    // .mlpackage는 디렉토리 번들이라 ** 글로브가 내부 파일까지 펼쳐 빌드 페이즈 오류 발생.
                    // 내부 파일을 제외하고 .mlpackage 폴더 자체를 CoreML 컴파일 페이즈에 올리기 위해 excluding 처리.
                    sources: [
                        .glob("Sources/**", excluding: ["Sources/*.mlpackage", "Sources/*.mlpackage/**"]),
                        .glob("Sources/*.mlpackage"),
                    ],
                    resources: hasResources ? ["Resources/**"] : nil,
                    dependencies: allDependencies,
                    settings: .settings(base: XCConfig.base)
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
                    dependencies: interfaceDependencies,
                    settings: .settings(base: XCConfig.base)
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
                    dependencies: [.target(name: name)],
                    settings: .settings(base: XCConfig.base)
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
                    infoPlist: .extendingDefault(with: [
                        "UIRequiresFullScreen": true,
                        "UILaunchScreen": ["UIColorName": "", "UIImageName": ""],
                        "NSCameraUsageDescription": "카메라로 알약을 촬영합니다.",
                        "NSPhotoLibraryUsageDescription": "갤러리에서 알약 사진을 선택합니다.",
                        "UIApplicationSceneManifest": .dictionary([
                            "UIApplicationSupportsMultipleScenes": .boolean(false),
                            "UISceneConfigurations": .dictionary([
                                "UIWindowSceneSessionRoleApplication": .array([
                                    .dictionary([
                                        "UISceneConfigurationName": .string("Default Configuration"),
                                        "UISceneDelegateClassName": .string("$(PRODUCT_MODULE_NAME).SceneDelegate"),
                                    ])
                                ])
                            ])
                        ]),
                    ]),
                    sources: ["Demo/Sources/**"],
                    dependencies: [.target(name: name)],
                    settings: .settings(base: XCConfig.base)
                )
            )
        }

        var schemes: [Scheme] = []
        if targets.contains(.demo) {
            schemes.append(
                .scheme(
                    name: "\(name)Demo",
                    buildAction: .buildAction(targets: [.target("\(name)Demo")]),
                    runAction: .runAction(executable: .target("\(name)Demo"))
                )
            )
        }

        return Project(
            name: name,
            settings: .settings(base: XCConfig.base, configurations: XCConfig.framework),
            targets: projectTargets + extraTargets,
            schemes: schemes + extraSchemes
        )
    }
}
