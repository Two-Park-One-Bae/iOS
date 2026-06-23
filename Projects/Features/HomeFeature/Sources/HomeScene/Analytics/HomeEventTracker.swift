import Core

enum HomeEvent: AmplitudeEventType {
    case viewHome
    case tapItem(id: Int)

    var eventName: String {
        switch self {
        case .viewHome: return "home_view"
        case .tapItem: return "home_item_tap"
        }
    }

    var properties: [String: Any]? {
        switch self {
        case .viewHome: return nil
        case .tapItem(let id): return ["item_id": id]
        }
    }
}
