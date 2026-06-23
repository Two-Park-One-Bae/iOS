import Foundation

public enum NetworkConfig {
    public static let baseURL = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String ?? ""
}
