import Foundation
import TimerDomain
import UserNotifications
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(AlarmKit)
import AlarmKit
#endif

// 위젯 전용 App Group 접근 (NM-302) — 앱(Data/TimerRepository)과 "같은 suite·같은 키"를 읽고 쓴다.
// 위젯 익스텐션은 Data/TimerFeature 를 링크하지 않으므로(경량 유지) 최소 저장소를 자체 정의한다.
// 프리셋 데이터는 앱이 소유하고, 위젯은 id 로 조회 + 원탭 시작(러닝 타이머 추가)만 한다.
enum TimerPresetStore {

    static let appGroup = "group.app.nursemate.timer"

    private enum Keys {
        static let presets = "care.timer.presets"     // [TimerPresetModel]
        static let timers = "care.timer.timers"       // [TreatmentTimerModel]
        static let snapshotAt = "care.timer.snapshotAt"
        static let alarmAuthorized = "care.timer.alarmAuthorized"  // NM-360 앱이 캐시하는 알람 권한 승인 여부
    }

    private static var store: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    // MARK: - 알람 권한 게이트 (NM-360)

    /// 앱이 App Group 에 캐시한 알람 권한 승인 여부. 위젯 원탭 버튼 라우팅에 사용:
    /// true → AppIntent 로 조용히 시작 / false·미설정 → 딥링크로 앱을 열어 앱 게이트가 권한을 처리.
    /// (앱을 한 번도 안 연 신규 설치는 false 로 시작해 안전하게 앱을 경유한다.)
    static var alarmAuthorized: Bool {
        store.bool(forKey: Keys.alarmAuthorized)
    }

    /// 실시작 직전 최종 확인용 — 위젯 프로세스에서 시스템 권한 상태를 직접 읽는다.
    /// 캐시 플래그가 stale(승인으로 굳어졌지만 실제로는 해제됨)해도 죽는 타이머를 만들지 않는다.
    private static var isAlarmGranted: Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            return AlarmManager.shared.authorizationState == .authorized
        }
        #endif
        // 26.1 미만은 위젯 버튼이 애초에 딥링크로만 라우팅되어 이 경로로 오지 않음 — 방어적으로 캐시 신뢰.
        return alarmAuthorized
    }

    // MARK: - 프리셋 조회 (위젯 설정 선택지 · 렌더용)

    static func loadPresets() -> [TimerPresetModel] {
        guard let data = store.data(forKey: Keys.presets),
              let list = try? JSONDecoder().decode([TimerPresetModel].self, from: data)
        else { return [] }
        return list
    }

    static func preset(id: UUID) -> TimerPresetModel? {
        loadPresets().first { $0.id == id }
    }

    // MARK: - 원탭 시작 (앱 안 열고 조용히 — NM-302 "+" 프리셋 시작)

    /// 러닝 타이머를 공유 저장소에 추가하고 만료 알람을 예약한다.
    /// 앱은 다음 활성화 때 `TimerUseCase.reload()`(SceneDelegate)로 이 타이머를 흡수한다.
    /// 버전별: iOS 26.1+ → AlarmKit(앱과 동일), 미만 → 로컬 알림.
    static func startTimer(preset: TimerPresetModel) async {
        // 안전망(NM-360): 알람 미승인이면 조용히 죽는 타이머를 만들지 않는다.
        // 위젯 버튼은 승인 시에만 AppIntent 로 라우팅하지만, 캐시 플래그가 stale 일 수 있어 실시작 직전 재확인.
        guard isAlarmGranted else { return }

        let endAt = Date().addingTimeInterval(TimeInterval(preset.duration))
        let timer = TreatmentTimerModel(
            label: preset.label,
            category: preset.category,
            duration: preset.duration,
            endAt: endAt,
            state: .running
        )

        var timers = loadTimers()
        timers.append(timer)
        saveTimers(timers)

        await scheduleAlarm(
            id: timer.id,
            label: timer.label,
            categoryName: timer.category.displayName,
            fireDate: endAt,
            duration: timer.duration
        )
        reloadWidgets()
    }

    /// [완료] 등으로 타이머 제거 (위젯 stop 인텐트가 호출).
    static func removeTimer(id: UUID) {
        var timers = loadTimers()
        timers.removeAll { $0.id == id }
        saveTimers(timers)
    }

    // MARK: - Private (알람 예약 · 타이머 저장)

    // iOS 26.1+ 는 AlarmKit(앱 경로와 동일한 시스템 알람), 미만·실패 시 로컬 알림 폴백.
    private static func scheduleAlarm(id: UUID, label: String, categoryName: String, fireDate: Date, duration: Int) async {
        let remaining = max(1, Int(fireDate.timeIntervalSinceNow.rounded()))
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            do {
                try await TimerWidgetAlarmScheduler.schedule(id: id, label: label, categoryName: categoryName, seconds: remaining)
                return
            } catch {
                // 권한 미승인 등 실패 → 로컬 알림 폴백
            }
        }
        #endif
        scheduleExpiryNotification(id: id, label: label, duration: duration, fireDate: fireDate)
    }

    private static func loadTimers() -> [TreatmentTimerModel] {
        guard let data = store.data(forKey: Keys.timers),
              let list = try? JSONDecoder().decode([TreatmentTimerModel].self, from: data)
        else { return [] }
        return list
    }

    private static func saveTimers(_ timers: [TreatmentTimerModel]) {
        if let data = try? JSONEncoder().encode(timers) {
            store.set(data, forKey: Keys.timers)
        }
        // 워치 동기화 트리거 — 앱/워치가 최신 스냅샷을 인지.
        store.set(Date().timeIntervalSince1970, forKey: Keys.snapshotAt)
    }

    // 만료 로컬 알림(기본 폴백) — 익스텐션에서도 예약 가능하다.
    // 카테고리(CARE_TIMER_ALARM · [완료] 액션)는 앱이 등록하므로 identifier 만 맞춘다.
    // (iOS 26.1+ AlarmKit 승격은 후속 — 위젯 프로세스 AlarmKit 예약은 실기기 실측 필요)
    private static func scheduleExpiryNotification(id: UUID, label: String, duration: Int, fireDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "\(label) 종료"
        content.body = "\(Self.durationText(duration)) 타이머가 끝났어요"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "CARE_TIMER_ALARM"

        let interval = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id.uuidString, content: content, trigger: trigger)
        )
    }

    private static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func durationText(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h)시간") }
        if m > 0 { parts.append("\(m)분") }
        if s > 0 { parts.append("\(s)초") }
        return parts.isEmpty ? "0초" : parts.joined(separator: " ")
    }
}
