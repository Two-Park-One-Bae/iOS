import SwiftUI
import TimerDomain

// W1 활성 페이지 — 진행중 타이머 리스트 (spec/design OduYy / Ab5HV, NM-267)
//
// - 폰에서 받은 동기화 스냅샷(WatchConnectivityManager.snapshot)이 유일한 소스.
// - 만료(ringing)는 맨 위 경고색 카드 + [완료]. RUNNING/PAUSED 카드 탭 → W2 조작.
// - List 네이티브 사이징으로 워치 크기에 자동 적응.
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
                if connectivity.isStarting {
                    StartingView()
                } else {
                    EmptyTimersView(onStartFromPreset: onStartFromPreset)
                }
            } else {
                List {
                    // 기존 타이머가 있는데 새로 시작 중이면 맨 위에 로딩 카드.
                    if connectivity.isStarting {
                        StartingCardRow()
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
                    }
                    ForEach(timers) { timer in
                        Group {
                            if timer.state == .ringing {
                                RingingCardRow(timer: timer) {
                                    connectivity.send(command: .remove(id: timer.id))
                                }
                            } else {
                                NavigationLink {
                                    TimerActionView(timer: timer)
                                } label: {
                                    TimerCardRow(timer: timer)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
                    }
                }
                .listStyle(.plain)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // 만료(RINGING) 맨 위 → 진행 중(RUNNING) 만료 임박 순(endAt) → 일시정지(PAUSED) 맨 아래. (NM-361, 폰과 동일)
    // PAUSED는 카운트다운이 멈춰 '임박'이 아니므로(오래 정지 시 endAt이 과거가 됨) 상태로 먼저 가른다.
    private static func rank(_ timer: TreatmentTimerModel) -> Int {
        if timer.state == .ringing { return 0 }
        if timer.state == .running { return 1 }
        return 2   // paused
    }
    private static func order(_ a: TreatmentTimerModel, _ b: TreatmentTimerModel) -> Bool {
        rank(a) != rank(b) ? rank(a) < rank(b) : a.endAt < b.endAt
    }
}

// 프리셋 시작 직후(타이머 없음) — 폰이 타이머를 만들어 스냅샷을 보내는 짧은 동안 중앙 표시.
struct StartingView: View {
    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("시작하는 중…")
                .font(.caption)
                .foregroundStyle(WT.muted)
        }
        .padding()
    }
}

// 기존 타이머가 있을 때 — 목록 맨 위에 얹는 로딩 카드.
struct StartingCardRow: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("시작하는 중…")
                .font(.headline)
                .foregroundStyle(WT.muted)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(WT.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// 빈 상태 (spec/design Ab5HV) — 아이콘 원형 + 안내 + 프리셋 페이지 유도 CTA.
struct EmptyTimersView: View {
    let onStartFromPreset: () -> Void
    @ScaledMetric private var circle: CGFloat = 64

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(WT.card).frame(width: circle, height: circle)
                Image(systemName: "timer")
                    .font(.system(size: circle * 0.44))
                    .foregroundStyle(WT.muted)
            }
            Text("진행 중인 타이머가 없어요")
                .font(.headline)
                .foregroundStyle(WT.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
            Button(action: onStartFromPreset) {
                HStack(spacing: 4) {
                    Text("프리셋에서 시작하세요")
                        .font(.caption)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    WIcon(name: "ic_chevron_right", size: 12, color: WT.remaining)
                }
                .foregroundStyle(WT.remaining)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
    }
}
