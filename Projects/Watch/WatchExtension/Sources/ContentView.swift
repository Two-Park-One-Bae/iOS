import SwiftUI

// W1 — 좌우 스와이프 2페이지: 활성 타이머 ↔ 프리셋 (spec/feature/care-timer/README.md).
struct ContentView: View {
    private enum Page: Int { case active, preset }

    @State private var page: Page = .active

    var body: some View {
        // NavigationStack을 TabView 바깥에 — W2(상세) 푸시 시 전체를 덮어
        // 좌우 스와이프 페이지 전환이 상세 화면에서 동작하지 않게 한다.
        NavigationStack {
            TabView(selection: $page) {
                TimerListView(onStartFromPreset: { page = .preset })
                    .tag(Page.active)

                PresetPageView(onStarted: { page = .active })
                    .tag(Page.preset)
            }
            .tabViewStyle(.page)
        }
    }
}
