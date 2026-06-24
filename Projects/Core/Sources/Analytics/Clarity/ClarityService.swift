import Clarity

public enum ClarityService {
    public static func configure() {
        let config = ClarityConfig(projectId: Bundle.main.object(forInfoDictionaryKey: "CLARITY_PROJECT_ID") as? String ?? "")
        ClaritySDK.initialize(config: config)
    }
}
