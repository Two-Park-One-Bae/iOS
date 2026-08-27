import Foundation
import TimerDomain
#if canImport(WidgetKit)
import WidgetKit
#endif

// 위젯 전용 App Group 접근 (NM-302) — 앱(Data/TimerRepository)과 "같은 suite·같은 키"를 읽고 쓴다.
// 위젯 익스텐션은 Data/TimerFeature 를 링크하지 않으므로(경량 유지) 최소 저장소를 자체 정의한다.
// 프리셋 데이터는 앱이 소유하고, 위젯은 id 로 조회 + 원탭 시작(러닝 타이머 추가)만 한다.
enum TimerPresetStore {

    static let appGroup = "group.app.nursemate.care.timer"

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

    /// 무음 시작이 실패했을 때 캐시 플래그를 미승인으로 되돌리고 위젯을 다시 그린다 (NM-371).
    /// 위젯이 즉시 딥링크 분기로 바뀌어, 다음 탭부터는 버튼이 아니라 앱이 열린다.
    /// 앱은 다음 활성화 때 실제 권한 상태로 이 값을 다시 덮어쓴다.
    private static func markAlarmUnauthorized() {
        store.set(false, forKey: Keys.alarmAuthorized)
        reloadWidgets()
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

    /// 러닝 타이머를 공유 저장소에 추가하고 만료 알람(AlarmKit)을 예약한다.
    /// 앱은 다음 활성화 때 `TimerUseCase.reload()`(SceneDelegate)로 이 타이머를 흡수한다.
    ///
    /// 예약을 **먼저** 시도하고 성공했을 때만 타이머를 저장한다 (NM-371).
    /// 울리지 않는 타이머를 남기지 않으면서, 실패를 호출자에게 돌려줘 앱의 권한 게이트로 보낼 수 있다.
    ///
    /// - Returns: 무음 시작 성공 여부. `false` 면 호출자가 앱을 열어 권한 게이트를 태워야 한다.
    static func startTimer(preset: TimerPresetModel) async -> Bool {
        let endAt = Date().addingTimeInterval(TimeInterval(preset.duration))
        let timer = TreatmentTimerModel(
            label: preset.label,
            category: preset.category,
            duration: preset.duration,
            endAt: endAt,
            state: .running
        )

        guard await scheduleAlarm(
            id: timer.id,
            label: timer.label,
            categoryName: timer.category.displayName,
            fireDate: endAt
        ) else {
            markAlarmUnauthorized()
            return false
        }

        var timers = loadTimers()
        timers.append(timer)
        saveTimers(timers)

        // 위젯 백그라운드 시작은 앱 밖이라 timer_start(Firebase)가 유실됨 → 지연 큐에 기록.
        // 앱이 다음 활성화 때 SceneDelegate 에서 drain 해 발사한다.
        WidgetAnalyticsQueue.appendTimerStart(
            PendingWidgetTimerStart(
                presetLabel: preset.label,
                category: preset.category.displayName,
                durationSec: preset.duration,
                startedAt: Date()
            )
        )

        reloadWidgets()
        return true
    }

    /// [완료] 등으로 타이머 제거 (위젯 stop 인텐트가 호출).
    static func removeTimer(id: UUID) {
        var timers = loadTimers()
        // 앱 밖 AlarmKit [완료] → timer_complete 지연 기록(위젯은 Firebase 미링크).
        // 앱이 다음 활성화 때 SceneDelegate 에서 drain 해 발사한다.
        if let t = timers.first(where: { $0.id == id }) {
            WidgetAnalyticsQueue.appendTimerComplete(
                PendingWidgetTimerComplete(
                    category: t.category.displayName, durationSec: t.duration, completedAt: Date()))
        }
        timers.removeAll { $0.id == id }
        saveTimers(timers)
    }

    // MARK: - Private (알람 예약 · 타이머 저장)

    /*
     AlarmKit 예약 (iOS 26.1+). 성공 여부를 돌려준다.

     실패해도 로컬 알림으로 강등하지 않는다 (NM-371). 로컬 알림은 별도 권한(UNAuthorization)이
     필요해서, 알람 권한이 없는 사용자는 알림 권한도 없을 수 있고 그러면 진짜로 아무것도
     울리지 않는다(ISS-05 재현). 권한 문제는 앱의 게이트가 요청으로 풀어야 한다.

     26.1 미만은 위젯이 버튼 대신 딥링크로 렌더되어 이 경로로 오지 않는다.
     혹시 오더라도 false 를 돌려 앱을 열게 하면 앱이 정식 시작한다.
     */
    private static func scheduleAlarm(id: UUID, label: String, categoryName: String, fireDate: Date) async -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            let remaining = max(1, Int(fireDate.timeIntervalSinceNow.rounded()))
            do {
                try await TimerWidgetAlarmScheduler.schedule(
                    id: id, label: label, categoryName: categoryName, seconds: remaining
                )
                return true
            } catch {
                return false
            }
        }
        #endif
        return false
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
