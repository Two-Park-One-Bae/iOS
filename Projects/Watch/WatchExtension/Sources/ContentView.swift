import SwiftUI

// W1 — 좌우 스와이프 2페이지: 활성 타이머 ↔ 프리셋 (spec/feature/care-timer/README.md).
struct ContentView: View {
    private enum Page: Int { case active, preset }

    @State private var page: Page = .active

    @EnvironmentObject private var connectivity: WatchConnectivityManager
    @StateObject private var ringing = RingingCoordinator()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPresetGrid = false   // 컴플리케이션 딥링크 목적지(D7MpNK)

    var body: some View {
        // 울림 화면은 fullScreenCover 대신 ZStack 오버레이로 — watchOS 에서 확실히 최상단을 덮는다.
        ZStack {
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

            if let timer = ringing.ringing {
                AlarmRingingView(timer: timer) {
                    connectivity.send(command: .remove(id: timer.id))
                    WatchNotificationScheduler.cancel(id: timer.id)
                    ringing.dismiss()   // 낙관적 닫기 — 폰 스냅샷이 확정
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: ringing.ringing?.id)
        .onAppear {
            WatchNotificationScheduler.requestAuthorization()
            ringing.sync(connectivity.snapshot)
        }
        .onChange(of: connectivity.snapshot) { _, snapshot in ringing.sync(snapshot) }
        // 백그라운드에서 만료 스냅샷이 도착했다가 포그라운드로 돌아온 경우 반영.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { ringing.sync(connectivity.snapshot) }
        }
        // 컴플리케이션 탭(nursemate://presets) → 프리셋 그리드(D7MpNK) 시트로 표시.
        .onOpenURL { url in
            if url.host == "presets" { showPresetGrid = true }
        }
        .sheet(isPresented: $showPresetGrid) {
            PresetGridView(onStarted: { showPresetGrid = false })
                .environmentObject(connectivity)
        }
    }
}
