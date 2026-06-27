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

    public static func identify(key: String, value: Any) {
        let identify = Identify()
        identify.set(property: key, value: value)
        instance.identify(identify: identify)
    }
}
