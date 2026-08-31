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
        // Debug: 즉시 반영(캐시 0). Release: 15분.
        //
        // 12시간이었는데 낮췄다. 이 값은 **원격 제어가 얼마나 늦게 먹히는가**를 그대로 정한다 —
        // 실시간 리스너는 앱이 포그라운드일 때만 연결이 살아 있어(Firebase 설계) 백그라운드에
        // 있던 사용자는 복귀 시 fetch 에 의존하는데, 그게 12시간 막혀 있으면 점검 모드가
        // 사실상 안 듣는다. 급할 때 쓰려고 둔 장치가 급할 때 안 되는 값이었다.
        //
        // 15분이면 리스너가 놓쳐도 그 안에 반영된다. Remote Config 는 호출 비용이 없고
        // 포그라운드 복귀마다 최대 4회/시간 수준이라 부담도 없다.
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 900
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

    // MARK: - 실시간 갱신

    private var updateListener: ConfigUpdateListenerRegistration?

    /// 서버가 값을 게시하면 **즉시** 받아 반영한다. 반영되면 `.remoteConfigDidUpdate` 를 던진다.
    ///
    /// **이게 없으면 점검 모드가 실전에서 동작하지 않는다.** 릴리즈 빌드는
    /// `minimumFetchInterval` 이 12시간이라 `fetchAndActivate()` 가 그 안에는 서버로 가지 않고
    /// 캐시만 돌려준다. 점검 모드를 켜야 하는 순간은 **이미 앱을 쓰고 있는 사용자**에게 알릴
    /// 때인데, 그 사람들은 전부 캐시를 갖고 있어 최대 12시간 동안 옛 값을 본다.
    ///
    /// 테스트에서 안 걸리는 이유도 같다 — Xcode 빌드는 간격이 0 이고, 새로 설치한 직후는
    /// 캐시가 없어 첫 fetch 가 서버로 간다. **이미 깔린 릴리즈 앱에서만** 재현된다.
    ///
    /// Firebase 권장 구조가 "시작 시 fetch + 사용 중 실시간 청취" 다. 실시간은 폴링을 대체하지
    /// 않는다 — 연결이 **포그라운드에서만** 유지되므로 앱을 새로 켤 때의 최신화는 여전히
    /// `fetchAndActivate()` 몫이다. 그래서 `minimumFetchInterval` 은 12시간 그대로 둔다.
    public func startListening() {
        guard updateListener == nil else { return }
        updateListener = remoteConfig.addOnConfigUpdateListener { [weak self] update, error in
            if let error {
                #if DEBUG
                print("⚠️ RemoteConfig 실시간 수신 실패: \(error)")
                #endif
                FirebaseService.recordError(error)
                return
            }
            #if DEBUG
            print("🔔 RemoteConfig 실시간 갱신 — 변경된 키: \(update?.updatedKeys ?? [])")
            #endif

            // **포그라운드 복귀 경로와 같은 함수를 쓴다.** 예전엔 여기서 activate 를 직접
            // 불렀는데, 값은 받아 왔지만 화면에 반영되지 않았다 — 앱을 백그라운드에 보냈다
            // 돌아와야 그제서야 점검창이 떴다. 복귀 시 도는 fetchAndActivate() 가 그때
            // activate 를 대신 해준 것이다.
            //
            // 두 경로가 같은 코드를 타면 한쪽만 동작하는 상황이 생길 수 없다.
            // fetch 가 캐시에 막혀도 activate 는 수행되므로 여기서도 안전하다.
            Task { @MainActor in
                await self?.fetchAndActivate()
                NotificationCenter.default.post(name: .remoteConfigDidUpdate, object: nil)
            }
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

public extension Notification.Name {

    /// Remote Config 값이 **실시간으로** 갱신됐다 (`RemoteConfigService.startListening`).
    ///
    /// 게이트 화면처럼 **떠 있는 동안에도 값이 바뀌면 따라가야 하는** 곳이 받는다.
    /// 앱 시작 시점의 최신화는 `fetchAndActivate()` 가 담당하므로 이 알림과 무관하다.
    static let remoteConfigDidUpdate = Notification.Name("nursemate.remoteConfig.didUpdate")
}
