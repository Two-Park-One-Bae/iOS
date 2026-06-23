import Core

struct AppLaunchEvent: AmplitudeEventType {
    var eventName: String { "app_launch" }
    var properties: [String: Any]? { nil }
}
