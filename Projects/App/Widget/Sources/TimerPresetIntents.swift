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

    public func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: presetId),
              let preset = TimerPresetStore.preset(id: uuid) else { return .result() }
        TimerPresetStore.startTimer(preset: preset)   // 앱 안 열고 조용히 시작
        return .result()
    }
}

// MARK: - 딥링크

public enum TimerWidgetDeepLink {
    /// 프리셋 관리(타이머 탭) 진입.
    public static let pickPreset = URL(string: "nursemate://timer/preset/pick")!
    /// 미설정 위젯 탭 → 위젯 설정 방법 온보딩.
    public static let howTo = URL(string: "nursemate://timer/widget/howto")!
}
