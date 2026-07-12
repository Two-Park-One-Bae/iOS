import WidgetKit
import SwiftUI
import AppIntents
import TimerDomain

// 잠금화면 프리셋 위젯 (NM-302) — 프리셋을 골라 원탭 시작, 미설정 슬롯은 "+".
// 스펙: 홈 화면 위젯은 MVP 제외 → 잠금화면 accessory 패밀리만 지원.
// 디자인: DESIGN.pen CZQbm(3개)·EPbtk(4개) — 라벨(키워드) 위, timer 아이콘 + "N분" 아래.

// MARK: - Timeline

struct PresetEntry: TimelineEntry {
    let date: Date
    let preset: TimerPresetModel?   // nil = 미설정("+")
}

// 위젯 설정에서 고른 프리셋 id 로 App Group 의 실시간 데이터를 읽는다.
// → 슬롯마다 다른 프리셋, 앱에서 프리셋을 고치면 reload 시 반영.
struct PresetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PresetEntry {
        PresetEntry(date: Date(), preset: nil)
    }

    func snapshot(for configuration: SelectPresetWidgetIntent, in context: Context) async -> PresetEntry {
        PresetEntry(date: Date(), preset: resolve(configuration))
    }

    func timeline(for configuration: SelectPresetWidgetIntent, in context: Context) async -> Timeline<PresetEntry> {
        Timeline(entries: [PresetEntry(date: Date(), preset: resolve(configuration))], policy: .never)
    }

    private func resolve(_ configuration: SelectPresetWidgetIntent) -> TimerPresetModel? {
        guard let id = configuration.preset?.id else { return nil }
        return TimerPresetStore.preset(id: id)
    }
}

// MARK: - Views (패밀리별)

struct PresetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PresetEntry

    var body: some View {
        switch family {
        case .accessoryCircular: CircularView(preset: entry.preset)
        default:                 RectangularView(preset: entry.preset)
        }
    }
}

// 잠금화면 가로 accessoryRectangular — 키워드(위) + timer 아이콘 + "N분"(아래).
struct RectangularView: View {
    let preset: TimerPresetModel?

    var body: some View {
        if let preset {
            Button(intent: StartPresetTimerIntent(presetId: preset.id)) {
                content(preset: preset)
            }
            .buttonStyle(.plain)
        } else {
            // 잠금화면 accessory 는 Link 가 잘 안 먹으므로 widgetURL 로 앱(온보딩)을 연다.
            emptyContent.widgetURL(TimerWidgetDeepLink.howTo)
        }
    }

    private func content(preset: TimerPresetModel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(preset.label)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            HStack(spacing: 3) {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .semibold))
                Text(preset.widgetDurationText)
                    .font(.system(size: 16, weight: .bold))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var emptyContent: some View {
        VStack(spacing: 3) {
            Image(systemName: "plus.circle.fill").font(.system(size: 20))
            Text("탭하여 설정").font(.system(size: 10, weight: .medium))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 잠금화면 원형 accessoryCircular — 아이콘 + 분(초소형).
struct CircularView: View {
    let preset: TimerPresetModel?

    var body: some View {
        if let preset {
            Button(intent: StartPresetTimerIntent(presetId: preset.id)) {
                VStack(spacing: 1) {
                    Image(systemName: "timer").font(.system(size: 12))
                    Text("\(preset.duration / 60)").font(.system(size: 13, weight: .bold))
                }
            }
            .buttonStyle(.plain)
        } else {
            VStack(spacing: 2) {
                Image(systemName: "plus.circle.fill").font(.system(size: 16))
                Text("탭하여 설정")
                    .font(.system(size: 9, weight: .medium))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetURL(TimerWidgetDeepLink.howTo)
        }
    }
}

// MARK: - Widget

public struct TimerPresetWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        // AppIntentConfiguration — 위젯마다 프리셋을 설정으로 지정(잠금화면 슬롯별로 다르게).
        AppIntentConfiguration(
            kind: "TimerPresetWidget",
            intent: SelectPresetWidgetIntent.self,
            provider: PresetProvider()
        ) { entry in
            PresetWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("처치 타이머")
        .description("프리셋을 골라 잠금화면에서 원탭으로 시작하세요.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}

// MARK: - 표기 헬퍼

private extension TimerPresetModel {
    /// 위젯 표기용 — 900→"15분", 7200→"2시간", 5400→"1시간 30분".
    var widgetDurationText: String {
        TimerPresetStore.durationText(duration)
    }
}
