import Moya

public enum HomeAPI {
    case getItems
    case getItemDetail(id: Int)
}

extension HomeAPI: TargetType {
    public var baseURL: URL { URL(string: NetworkConfig.baseURL)! }

    public var path: String {
        switch self {
        case .getItems: return "/home/items"
        case .getItemDetail(let id): return "/home/items/\(id)"
        }
    }

    public var method: Moya.Method {
        switch self {
        case .getItems, .getItemDetail: return .get
        }
    }

    public var task: Task { .requestPlain }

    public var headers: [String: String]? {
        ["Content-Type": "application/json"]
    }
}
