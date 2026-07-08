import SwiftUI
import TimerDomain

// W1 활성 페이지 — 진행중 타이머 리스트 (spec/feature/care-timer/README.md, NM-267)
//
// - 폰에서 받은 동기화 스냅샷(WatchConnectivityManager.snapshot)이 유일한 소스.
// - 만료(ringing)는 맨 위 경고색 카드 — 폰 C1과 동일.
// - 프라이버시 규칙: 처치 키워드 + 분류 태그 + 남은 시간만 노출(메모 없음).
// - 카드 탭 조작(일시정지/재개·정지)·프리셋 페이지는 별도(W2 / W1P).
struct TimerListView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager

    /// 빈 상태 CTA 탭 — 프리셋 페이지로 전환(ContentView가 소유).
    let onStartFromPreset: () -> Void

    private var timers: [TreatmentTimerModel] {
        (connectivity.snapshot?.timers ?? []).sorted(by: Self.order)
    }

    var body: some View {
        Group {
            if timers.isEmpty {
                EmptyTimersView(onStartFromPreset: onStartFromPreset)
            } else {
                // 1초마다 남은 시간 갱신 — 타이머 수동 관리 없이 TimelineView로.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    List(timers) { timer in
                        TimerCardRow(timer: timer, now: context.date)
                            .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                    }
                    .listStyle(.carousel)
                }
            }
        }
        .navigationTitle("타이머")
    }

    // 만료(ringing) 카드가 맨 위, 그다음 만료 임박 순(endAt 오름차순).
    private static func order(_ a: TreatmentTimerModel, _ b: TreatmentTimerModel) -> Bool {
        if (a.state == .ringing) != (b.state == .ringing) {
            return a.state == .ringing
        }
        return a.endAt < b.endAt
    }
}

// 빈 상태 — 프리셋 페이지로 유도. CTA를 누르면 프리셋 페이지로 전환.
struct EmptyTimersView: View {
    let onStartFromPreset: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "timer")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("진행 중인 타이머 없음")
                .font(.headline)
            Button(action: onStartFromPreset) {
                HStack(spacing: 4) {
                    Text("프리셋에서 시작하세요")
                    Image(systemName: "chevron.right")
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        }
        .multilineTextAlignment(.center)
        .padding()
    }
}
