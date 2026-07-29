import Clarity

public enum ClarityService {
    public static func configure() {
        let config = ClarityConfig(projectId: Bundle.main.object(forInfoDictionaryKey: "CLARITY_PROJECT_ID") as? String ?? "")
        ClaritySDK.initialize(config: config)
    }

    /// 세션을 커스텀 유저 ID(서버 기기 식별자)로 묶는다 — Amplitude·Crashlytics와 동일 device_id.
    /// 반드시 `configure()`(initialize) 이후 호출. 값 제약: 1~255자·공백만 불가(UUID는 충족).
    public static func setUserID(_ userID: String) {
        _ = ClaritySDK.setCustomUserId(userID)
    }
}
