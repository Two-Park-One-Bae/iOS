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
        // 앱 버전의 기본값 — 로컬·디버그 빌드용. 배포 레인은 젠킨스 APP_VERSION 을 xcargs 로 덮어쓴다(Fastfile).
        // 앱·워치·익스텐션 Info.plist 의 CFBundleShortVersionString 이 모두 이 값을 본다.
        "MARKETING_VERSION": "2.0.2",
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
