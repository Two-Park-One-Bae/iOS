import Foundation
import AmplitudeSwift

public protocol AmplitudeEventType {
    var eventName: String { get }
    var properties: [String: Any]? { get }
}

public enum AmplitudeService {
    private static let instance = Amplitude(
        configuration: Configuration(
            apiKey: Bundle.main.object(forInfoDictionaryKey: "AMPLITUDE_API_KEY") as? String ?? ""
        )
    )

    public static func track(_ event: AmplitudeEventType) {
        instance.track(
            eventType: event.eventName,
            eventProperties: event.properties
        )
    }

    public static func setUserID(_ userID: String) {
        instance.setUserId(userId: userID)
    }

    /// 로그아웃 — 사용자 결합을 끊는다. 안 끊으면 다음 로그인 전까지의 이벤트가
    /// **이전 사용자에게 붙는다**(기기를 공유하는 병동 환경에서 실제로 문제가 된다).
    public static func clearUserID() {
        instance.setUserId(userId: nil)
    }

    public static func identify(key: String, value: Any) {
        let identify = Identify()
        identify.set(property: key, value: value)
        instance.identify(identify: identify)
    }
}
