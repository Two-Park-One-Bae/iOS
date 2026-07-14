import WidgetKit
import SwiftUI

// NM-303 워치 컴플리케이션 — 시계 페이스에 올려 탭하면 앱의 프리셋 그리드(D7MpNK)를 연다.
// 데이터 표시는 없는 "런처" 성격 — widgetURL(nursemate://presets)로 앱을 열고, 앱이 시트로 그리드 표시.
@main
struct WatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        PresetLauncherComplication()
    }
}

struct PresetLauncherComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PresetLauncher", provider: PresetLauncherProvider()) { _ in
            PresetLauncherView()
                .widgetURL(URL(string: "nursemate://presets"))
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("프리셋 시작")
        .description("탭하면 프리셋 목록이 열립니다.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Timeline (정적 — 상태 표시 없음)

struct PresetLauncherEntry: TimelineEntry {
    let date: Date
}

struct PresetLauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> PresetLauncherEntry {
        PresetLauncherEntry(date: Date())
    }
    func getSnapshot(in context: Context, completion: @escaping (PresetLauncherEntry) -> Void) {
        completion(PresetLauncherEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PresetLauncherEntry>) -> Void) {
        completion(Timeline(entries: [PresetLauncherEntry(date: Date())], policy: .never))
    }
}

// MARK: - 표시 (패밀리별)

struct PresetLauncherView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("프리셋 시작", systemImage: "timer")
        case .accessoryRectangular:
            HStack(spacing: 6) {
                Image(systemName: "timer")
                Text("프리셋 시작")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryCircular, .accessoryCorner:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "timer")
                    .font(.system(size: 18, weight: .semibold))
            }
        default:
            Image(systemName: "timer")
        }
    }
}
