import AppIntents
import Foundation

// MARK: - 위젯 설정 인텐트 (위젯별 프리셋 지정)

// 위젯(잠금화면 슬롯 포함) 편집 시 이 파라미터로 프리셋을 고른다. 위젯마다 다른 프리셋 가능.
public struct SelectPresetWidgetIntent: WidgetConfigurationIntent {
    public static let title: LocalizedStringResource = "프리셋 선택"
    public static let description = IntentDescription("이 위젯으로 바로 시작할 프리셋을 고르세요.")

    @Parameter(title: "프리셋")
    public var preset: TimerPresetEntity?   // nil = 미설정("+")

    public init() {}
    public init(preset: TimerPresetEntity?) { self.preset = preset }
}

// MARK: - 원탭 시작 인텐트 (위젯 버튼 — 앱 안 열고 백그라운드 실행)

public struct StartPresetTimerIntent: AppIntent {
    public static let title: LocalizedStringResource = "프리셋으로 타이머 시작"

    @Parameter(title: "Preset ID", default: "")
    public var presetId: String

    public init() {}
    public init(presetId: UUID) { self.presetId = presetId.uuidString }

    // 26.1+ = 무음(AlarmKit가 카운트다운 표시 담당). 미만 = 앱을 열어 정식 시작
    // (Live Activity 는 앱 포그라운드에서만 시작 가능 → 위젯 프로세스에선 못 띄운다).
    public var openAppWhenRun: Bool {
        if #available(iOS 26.1, *) { return false }
        return true
    }

    public func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: presetId),
              let preset = TimerPresetStore.preset(id: uuid) else { return .result() }
        if #available(iOS 26.1, *) {
            await TimerPresetStore.startTimer(preset: preset)   // 무음 AlarmKit
        } else {
            TimerPresetStore.setPendingStart(preset.id)         // 앱이 열려서 정식 시작(Live Activity)
        }
        return .result()
    }
}

// MARK: - 딥링크

public enum TimerWidgetDeepLink {
    /// 프리셋 관리(타이머 탭) 진입.
    public static let pickPreset = URL(string: "nursemate://timer/preset/pick")!
    /// 미설정 위젯 탭 → 위젯 설정 방법 온보딩.
    public static let howTo = URL(string: "nursemate://timer/widget/howto")!
    /// 런처 위젯 탭 → 전체 프리셋에서 골라 시작.
    public static let quickStart = URL(string: "nursemate://timer/quickstart")!
}
