import SwiftUI

// W1 — 좌우 스와이프 2페이지: 활성 타이머 ↔ 프리셋 (spec/feature/care-timer/README.md).
struct ContentView: View {
    private enum Page: Int { case active, preset }

    @State private var page: Page = .active

    var body: some View {
        TabView(selection: $page) {
            NavigationStack {
                TimerListView(onStartFromPreset: { page = .preset })
            }
            .tag(Page.active)

            NavigationStack {
                PresetPageView()
            }
            .tag(Page.preset)
        }
        .tabViewStyle(.page)
    }
}
