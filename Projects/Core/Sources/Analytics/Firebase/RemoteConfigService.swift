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
        // Firebase 권장 프로덕션 값. 짧게 잡는 건 문서상 **개발용**이고, 낮은 값으로 배포하면
        // 시간당 서버 쿼터에 걸린다.
        //
        // 이 간격보다 빨리 반영되는 경로는 실시간 리스너뿐이다 — 그건 만료를 보지 않는다.
        // 다만 리스너는 보장 장치가 아니므로(`startListening` 주석), **점검 모드가 최대 12시간
        // 늦게 걸릴 수 있다**는 뜻이 된다.
        //
        // 그 지연이 문제가 되면 이 값을 낮추는 것보다 **백엔드가 점검 시 503 + `MAINTENANCE_MODE`
        // 를 내려주고 앱이 그걸 받아 게이트를 띄우는** 편이 낫다. 즉시 반영되고 추가 요청이 없다.
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

    /// 이미 fetch 된 값을 활성화한다. **네트워크를 타지 않는다.**
    @discardableResult
    public func activate() async -> Bool {
        do {
            return try await remoteConfig.activate()
        } catch {
            FirebaseService.recordError(error)
            return false
        }
    }

    // MARK: - 실시간 갱신

    private var updateListener: ConfigUpdateListenerRegistration?

    /// 서버가 값을 게시하면 받아서 반영하고 `.remoteConfigDidUpdate` 를 던진다.
    ///
    /// **best-effort 다. 이것만 믿으면 안 된다.** 실기기에서 콜백이 한 번도 오지 않는 경우를
    /// 확인했다(NM-423). 원인 후보를 SDK 소스(`RCNConfigRealtime.m`)에서 확인한 바:
    ///
    ///  - 스트림은 일반 fetch 와 **다른 호스트**(`firebaseremoteconfigrealtime.googleapis.com`)를
    ///    쓴다. 여기만 막혀도 fetch 는 멀쩡해 증상이 "가끔 안 된다"로 보인다.
    ///  - **실패가 조용하다.** 403 은 물론 다른 상태코드도 `FIRLogError` 로만 남기고
    ///    리스너에는 전파하지 않는다. 그래서 아래 `⚠️` 로그로도 안 잡힌다.
    ///  - 연결 수명이 330초라 끊기면 재연결하는데, 그 사이 변경은 재연결 시점에야 반영된다.
    ///  - 콜백은 서버가 알린 templateVersion 이 **클라이언트 보유 버전보다 클 때만** 돈다.
    ///    포그라운드 복귀 시 `fetchAndActivate()` 가 먼저 버전을 올리면 리스너는 조용해진다.
    ///
    /// 따라서 반영을 책임지는 건 `fetchAndActivate()`(앱 시작·포그라운드 복귀)이고
    /// 이 리스너는 그 위에 얹는 빠른 경로다.
    ///
    /// **한 가지 반직관적인 상호작용이 있다 — 캐시가 길수록 리스너가 잘 뜬다.** 위의 네 번째
    /// 항목 때문이다. 캐시가 짧으면 복귀 시 `fetchAndActivate()` 가 서버에 가서 클라이언트
    /// 버전을 먼저 올려버리고, 뒤이어 재연결한 리스너는 같은 버전을 받아 조용해진다.
    /// 캐시에 막히면 버전이 그대로라 리스너가 정상 발화한다. 기기에서 확인했다 —
    /// Debug 는 간격이 0 이라 리스너가 늘 가려져 있었고, 그래서 "리스너가 죽었다"고 보였다.
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

            // **여기서는 activate 만 한다.** 실시간 경로는 이미 fetch 를 끝냈고 activate 만
            // 안 한 상태다 — SDK 가 `getConfigUpdateForNamespace` 로 fetched 와 active 를
            // 비교해 변경 키를 뽑아 이 콜백을 부르기 때문이다(RCNConfigFetch.m).
            //
            // 그래서 `fetchAndActivate()` 를 부르면 손에 든 값을 두고 네트워크 왕복을 한 번
            // 더 하게 된다. 반영이 그만큼 늦어진다.
            Task { @MainActor in
                await self?.activate()
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
