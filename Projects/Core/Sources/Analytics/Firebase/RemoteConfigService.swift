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
        // Firebase 권장 프로덕션 기본값. 짧게 잡는 건 문서상 **개발용**이고, 낮은 값으로
        // 배포하면 시간당 서버 쿼터에 걸린다.
        //
        // 이 값이 길어도 긴급 상황은 `checkForOutage()` 가 캐시를 무시하고 즉시 받아온다.
        // 평상시 비용(하루 2회)과 장애 시 반영 속도를 둘 다 챙기는 게 그 조합이다.
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
    /// 따라서 실제 반영을 책임지는 건 **포그라운드 복귀 때 도는 `fetchAndActivate()`** 이고,
    /// 이 리스너는 그 위에 얹는 빠른 경로다. `minimumFetchInterval` 을 15분으로 낮춰 둔 이유도
    /// 같다 — 리스너가 놓쳐도 그 안에는 반영되게 하는 하한선이다.
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

    // MARK: - 장애 감지 시 즉시 확인

    private var lastOutageCheck: Date?

    /// 네트워크 실패가 감지됐을 때 **캐시를 무시하고** 최신 설정을 받아온다.
    ///
    /// **`minimumFetchInterval` 이 12시간이어도 이 경로는 뚫린다.** 만료 시간 0 을 넘기면
    /// `hasMinimumFetchIntervalElapsed` 가 항상 통과하기 때문이다(RCNConfigFetch.m).
    ///
    /// 시간이 아니라 **실패를 트리거로 삼는 이유**는, 서버가 죽었을 때 그 사실을 앱이 가장
    /// 먼저 알기 때문이다. 평상시엔 아무것도 하지 않다가 실제로 문제가 생긴 순간에만 움직여
    /// 폴링 비용 없이 즉시성을 얻는다.
    ///
    /// 그리고 이 경로는 **서버가 완전히 죽어도 동작한다.** Remote Config 는 구글이 호스팅하므로
    /// 우리 백엔드와 독립이다. 백엔드가 점검 응답(503)을 내려주는 방식은 서버가 살아 있어야만
    /// 쓸 수 있어서, 정작 장애 때 못 쓴다.
    ///
    /// 요청이 무더기로 실패해도 fetch 가 폭주하지 않도록 60초로 디바운스한다.
    public func checkForOutage() {
        Task { @MainActor in
            let now = Date()
            if let last = lastOutageCheck, now.timeIntervalSince(last) < Self.outageCheckDebounce {
                return
            }
            lastOutageCheck = now

            do {
                _ = try await remoteConfig.fetch(withExpirationDuration: 0)
                _ = try await remoteConfig.activate()
            } catch {
                FirebaseService.recordError(error)
                return
            }
            #if DEBUG
            print("🩺 장애 감지 — Remote Config 즉시 확인: 점검 \(isUnderMaintenance)")
            #endif
            NotificationCenter.default.post(name: .remoteConfigDidUpdate, object: nil)
        }
    }

    private static let outageCheckDebounce: TimeInterval = 60

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
