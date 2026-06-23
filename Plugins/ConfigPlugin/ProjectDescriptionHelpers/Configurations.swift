import ProjectDescription

public struct XCConfig {
    public static let framework: [Configuration] = [
        .debug(name: "Debug"),
        .release(name: "Release"),
    ]

    public static let app: [Configuration] = [
        .debug(name: "Debug"),
        .release(name: "Release"),
    ]
}
