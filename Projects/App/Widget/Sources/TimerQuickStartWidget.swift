import WidgetKit
import SwiftUI

// 런처 위젯 (잠금화면, NM-302) — 설정 없이, 탭하면 앱에서 전체 프리셋 중 하나를 골라 시작.
// 잠금 accessory 는 좁아 전체를 다 못 그리므로 "타이머 시작" 진입점만 두고 목록은 앱에서.

struct QuickStartEntry: TimelineEntry { let date: Date }

struct QuickStartProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickStartEntry { QuickStartEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (QuickStartEntry) -> Void) {
        completion(QuickStartEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickStartEntry>) -> Void) {
        completion(Timeline(entries: [QuickStartEntry(date: Date())], policy: .never))
    }
}

struct QuickStartView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .accessoryCircular {
                Image(systemName: "timer").font(.system(size: 20))
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "timer").font(.system(size: 15, weight: .semibold))
                    Text("타이머 시작").font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(TimerWidgetDeepLink.quickStart)
    }
}

public struct TimerQuickStartWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TimerQuickStartWidget", provider: QuickStartProvider()) { _ in
            QuickStartView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("타이머 빠른 시작")
        .description("탭하면 프리셋을 골라 바로 시작합니다.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}
