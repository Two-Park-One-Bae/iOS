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

    /*
     이 버튼 인텐트는 26.1+ 위젯에서만 렌더된다(무음 AlarmKit).
     26.1 미만은 위젯이 widgetURL 로 앱을 열어 정식 시작(TimerWidgetDeepLink.startPreset).

     무음 시작이 실패하면(알람 예약 불가) 앱을 열어 권한 게이트를 태운다 (NM-371).
     예전에는 여기서 조용히 return 해서 탭해도 아무 일도 일어나지 않았다.

     ForegroundContinuableIntent 는 앱 익스텐션에서 쓸 수 없어(@available(iOSApplicationExtension,
     unavailable)) OpenURLIntent 로 딥링크를 연다 — 앱의 startWithAlarmGate 가 권한을 요청한다.
     */
    public func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: presetId),
              let preset = TimerPresetStore.preset(id: uuid) else { return .result() }

        if await TimerPresetStore.startTimer(preset: preset) { return .result() }

        // 위젯은 startTimer 가 이미 딥링크 분기로 되돌려놨다(다음 탭부터는 버튼 없이 바로 앱).
        if #available(iOS 18.0, *) {
            return .result(opensIntent: OpenURLIntent(TimerWidgetDeepLink.startPreset(id: uuid)))
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
    /// 설정형 위젯(26.1 미만) 탭 → 앱 열어 해당 프리셋 정식 시작.
    public static func startPreset(id: UUID) -> URL {
        URL(string: "nursemate://timer/start?preset=\(id.uuidString)")!
    }
}
