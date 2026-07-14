import ProjectDescription

public struct XCConfig {
    private struct Path {
        static var debug: ProjectDescription.Path { .relativeToRoot("XCConfig/Debug.xcconfig") }
        static var release: ProjectDescription.Path { .relativeToRoot("XCConfig/Release.xcconfig") }
    }

    public static let base: SettingsDictionary = [
        "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
        "ENABLE_MODULE_VERIFIER": "YES",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "VERSIONING_SYSTEM": "apple-generic",
        "CURRENT_PROJECT_VERSION": "1",
        // Firebase(RemoteConfig 등) 정적 링크 시 ObjC 카테고리 dead-strip 방지
        "OTHER_LDFLAGS": ["$(inherited)", "-ObjC"],
    ]

    public static let framework: [Configuration] = [
        .debug(name: "Debug", xcconfig: Path.debug),
        .release(name: "Release", xcconfig: Path.release),
    ]

    public static let app: [Configuration] = [
        .debug(name: "Debug", xcconfig: Path.debug),
        .release(name: "Release", xcconfig: Path.release),
    ]
}
