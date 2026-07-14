import Foundation
import FirebaseRemoteConfig

/// Firebase Remote Config 래퍼.
///
/// 3가지 원격 제어를 담당한다.
///  - **강제 업데이트**: `min_supported_version` 미만이면 업데이트 유도(`isForceUpdateRequired`)
///  - **점검 모드**: `maintenance_mode` 가 true 면 점검 화면 노출(`isUnderMaintenance` / `maintenanceMessage`)
///  - **기능 플래그(A/B)**: 임의 키를 `bool(_:)` / `string(_:)` / `int(_:)` 로 조회
///
/// 사용 흐름: 앱 시작 시 `FirebaseService.configure()` 이후 `await RemoteConfigService.shared.fetchAndActivate()`
/// 를 한 번 호출하면, 이후 접근자들이 최신(또는 in-app 기본) 값을 반환한다.
public final class RemoteConfigService {
    public static let shared = RemoteConfigService()

    /// Remote Config 파라미터 키 — Firebase 콘솔에 동일한 이름으로 등록해야 한다.
    public enum Key: String {
        /// 지원하는 최소 앱 버전(semver 문자열, 예: "1.2.0"). 현재 버전이 이보다 낮으면 강제 업데이트.
        case minSupportedVersion = "min_supported_version"
        /// 점검 모드 on/off.
        case maintenanceMode = "maintenance_mode"
        /// 점검 안내 문구.
        case maintenanceMessage = "maintenance_message"
        /// 강제 업데이트 시 이동할 App Store URL(선택). 비어 있으면 버튼은 App Store 앱만 연다.
        case appStoreURL = "app_store_url"
    }

    private let remoteConfig: RemoteConfig

    private init() {
        remoteConfig = RemoteConfig.remoteConfig()

        let settings = RemoteConfigSettings()
        // Debug: 즉시 반영(캐시 0). Release: 12시간 캐시(서버 호출 최소화).
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 43_200
        #endif
        remoteConfig.configSettings = settings

        // 네트워크/최초 실행 시에도 안전하게 동작하도록 in-app 기본값 등록.
        remoteConfig.setDefaults([
            Key.minSupportedVersion.rawValue: "1.0.0" as NSString,
            Key.maintenanceMode.rawValue: false as NSNumber,
            Key.maintenanceMessage.rawValue: "" as NSString,
            Key.appStoreURL.rawValue: "" as NSString,
        ])
    }

    /// 서버에서 최신 값을 받아 활성화한다. 실패해도 기존(또는 기본) 값이 유지된다.
    /// - Returns: 새 값이 적용됐으면 `true`.
    @discardableResult
    public func fetchAndActivate() async -> Bool {
        do {
            let status = try await remoteConfig.fetchAndActivate()
            return status == .successFetchedFromRemote || status == .successUsingPreFetchedData
        } catch {
            FirebaseService.recordError(error)
            return false
        }
    }

    // MARK: - 강제 업데이트

    /// 서버가 요구하는 최소 지원 버전.
    public var minSupportedVersion: String {
        remoteConfig[Key.minSupportedVersion.rawValue].stringValue
    }

    /// 현재 앱 버전(`CFBundleShortVersionString`)이 최소 지원 버전보다 낮은지.
    public var isForceUpdateRequired: Bool {
        guard let current = Self.currentAppVersion else { return false }
        return Self.isVersion(current, lowerThan: minSupportedVersion)
    }

    /// 강제 업데이트 버튼이 열 App Store URL(콘솔 `app_store_url`). 미설정이면 nil.
    public var appStoreURL: URL? {
        let raw = remoteConfig[Key.appStoreURL.rawValue].stringValue
        return raw.isEmpty ? nil : URL(string: raw)
    }

    // MARK: - 점검 모드

    /// 점검 모드 여부.
    public var isUnderMaintenance: Bool {
        remoteConfig[Key.maintenanceMode.rawValue].boolValue
    }

    /// 점검 안내 문구(비어 있으면 기본 문구는 호출부에서 처리).
    public var maintenanceMessage: String {
        remoteConfig[Key.maintenanceMessage.rawValue].stringValue
    }

    // MARK: - 기능 플래그 (A/B) — 임의 키 조회

    public func bool(_ key: String, default fallback: Bool = false) -> Bool {
        let value = remoteConfig[key]
        return value.source == .static ? fallback : value.boolValue
    }

    public func string(_ key: String, default fallback: String = "") -> String {
        let value = remoteConfig[key]
        return value.source == .static ? fallback : value.stringValue
    }

    public func int(_ key: String, default fallback: Int = 0) -> Int {
        let value = remoteConfig[key]
        return value.source == .static ? fallback : value.numberValue.intValue
    }

    // MARK: - 버전 비교 유틸

    private static var currentAppVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    /// semver 문자열을 컴포넌트 단위(숫자)로 비교. `lhs < rhs` 면 true.
    /// 예) isVersion("1.2.0", lowerThan: "1.10.0") == true
    static func isVersion(_ lhs: String, lowerThan rhs: String) -> Bool {
        let l = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let r = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(l.count, r.count)
        for i in 0..<count {
            let a = i < l.count ? l[i] : 0
            let b = i < r.count ? r[i] : 0
            if a != b { return a < b }
        }
        return false
    }
}
