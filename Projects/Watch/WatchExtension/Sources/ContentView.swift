import SwiftUI

// W1 — 좌우 스와이프 2페이지: 활성 타이머 ↔ 프리셋 (spec/feature/care-timer/README.md).
struct ContentView: View {
    private enum Page: Int { case active, preset }

    @State private var page: Page = .active

    @EnvironmentObject private var connectivity: WatchConnectivityManager
    @State private var showPresetGrid = false   // 컴플리케이션 딥링크 목적지(D7MpNK)

    /*
     폰이 AlarmKit(26.1+)을 쓸 수 있는가.

     nil = 아직 스냅샷을 못 받음(미상) → 정상 UI 를 보여주고 폰에 위임한다.
     false 일 때만 안내로 교체 — 확실히 26.1 미만인 경우다.
     */
    private var phoneSupportsTimer: Bool {
        connectivity.snapshot?.alarmKitActive != false
    }

    var body: some View {
        Group {
            if phoneSupportsTimer {
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
            } else {
                WatchUnsupportedView()
            }
        }
        .onAppear {
            WatchNotificationScheduler.requestAuthorization()
        }
        // 컴플리케이션 탭(nursemate://presets) → 프리셋 그리드(D7MpNK) 시트로 표시.
        .onOpenURL { url in
            if url.host == "presets", phoneSupportsTimer { showPresetGrid = true }
        }
        .sheet(isPresented: $showPresetGrid) {
            PresetGridView(onStarted: { showPresetGrid = false })
                .environmentObject(connectivity)
        }
    }
}
