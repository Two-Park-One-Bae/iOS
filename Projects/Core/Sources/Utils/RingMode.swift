import Foundation

// 타이머 만료 알림 방식 (소리 / 무음). 설정·첫 시작 시트에서 선택, 알람 스케줄러가 참조.
// (AlarmKit 풀스크린을 유지하려면 무진동이 불가 — 무음도 기기 진동 설정에 따라 진동이 남. 2모드로 확정)
public enum RingMode: String, CaseIterable, Sendable {
    case sound       // 기본 알람음 + 진동 (무음 모드도 뚫음)
    case silent      // 무음 사운드 → 소리 없음(진동 여부는 기기 벨소리/진동 설정에 따름)
}

// 울림 방식 저장소. 앱·위젯·익스텐션이 같은 값을 보도록 앱 그룹 UserDefaults 공유.
public final class RingModeStore {
    public static let shared = RingModeStore()

    private let defaults: UserDefaults
    private let modeKey = "timer.ringMode"
    private let chosenKey = "timer.ringMode.chosen"

    // 앱·위젯·익스텐션 공유를 위해 앱 그룹 suite 사용.
    public init(defaults: UserDefaults = UserDefaults(suiteName: "group.app.nursemate.timer") ?? .standard) {
        self.defaults = defaults
    }

    // 현재 울림 방식. 미설정 시 기본 .sound.
    public var current: RingMode {
        get { RingMode(rawValue: defaults.string(forKey: modeKey) ?? "") ?? .sound }
        set {
            defaults.set(newValue.rawValue, forKey: modeKey)
            defaults.set(true, forKey: chosenKey)
        }
    }

    // 첫 시작 시트를 이미 봤는지(= 사용자가 한 번이라도 방식을 확정했는지).
    public var hasChosen: Bool {
        defaults.bool(forKey: chosenKey)
    }
}
