import SwiftUI
import TimerDomain

// W2 조작 (spec/design u45KPn) — 큰 진행률 링 + 남은시간/전체 + 상태별 버튼.
// 링 크기는 화면 폭 비율(containerRelativeFrame)로 적응. 텍스트는 minimumScaleFactor 로 잘림 방지.
struct TimerActionView: View {
    let timer: TreatmentTimerModel

    @EnvironmentObject var connectivity: WatchConnectivityManager
    @Environment(\.dismiss) private var dismiss

    private var isPaused: Bool { timer.state == .paused }
    private var isRinging: Bool { timer.state == .ringing }

    var body: some View {
        // 헤더·버튼은 고정 크기, 원은 남는 공간을 오토레이아웃으로 꽉 채운다(드래그 없음).
        VStack(spacing: 8) {
            // 뒤로가기 + 라벨(좌) … 분류(우). 디자인 색: 라벨=흰색, 분류=분류 색. (고정)
            HStack(spacing: 5) {
                Button { dismiss() } label: {
                    WIcon(name: "ic_chevron_left", size: 16, color: WT.accent)
                }
                .buttonStyle(.plain)
                Text(timer.label)
                    .foregroundStyle(WT.textPrimary)
                Spacer(minLength: 4)
                Text(timer.category.displayName)
                    .foregroundStyle(WT.category(timer.category))
            }
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            ringArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            actionButtons
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
        .ignoresSafeArea(.container, edges: .bottom)
        .toolbar(.hidden, for: .navigationBar)
    }

    // 원 — 가용 공간(헤더·버튼 제외)을 fit 으로 꽉 채우고, 텍스트는 실제 지름에 비례.
    private var ringArea: some View {
        GeometryReader { g in
            let d = min(g.size.width, g.size.height)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = timer.remainingSeconds(at: context.date)
                let progress = timer.duration > 0 ? Double(remaining) / Double(timer.duration) : 0
                ZStack {
                    ProgressRing(
                        progress: isRinging ? 1 : progress,
                        tint: isPaused ? WT.muted : (isRinging ? WT.ringingAccent : WT.accent),
                        lineWidth: max(5, d * 0.055)
                    )
                    VStack(spacing: 0) {
                        Text(isRinging ? "종료" : WatchFormat.countdown(remaining))
                            .font(.system(size: d * 0.22, weight: .bold, design: .rounded))
                            .foregroundStyle(WT.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(WatchFormat.duration(timer.duration))
                            .font(.system(size: d * 0.1))
                            .foregroundStyle(WT.muted)
                            .lineLimit(1)
                    }
                    .frame(width: d * 0.82)
                }
                .frame(width: d, height: d)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // 두 버튼을 나란히(가로) — 짧은 고정 폭으로 가운데.
    @ViewBuilder private var actionButtons: some View {
        HStack(spacing: 14) {
            switch timer.state {
            case .running:
                actionButton("일시정지", tint: WT.textPrimary,
                             icon: { WIcon(name: "ic_pause", size: 18, color: WT.textPrimary) }) {
                    send(.pause(id: timer.id))
                }
                stopButton
            case .paused:
                actionButton("재개", tint: WT.accent,
                             icon: { WIcon(name: "ic_play", size: 18, color: WT.accent) }) {
                    send(.resume(id: timer.id))
                }
                stopButton
            case .ringing:
                actionButton("완료", tint: WT.ringingAccent, filled: true,
                             icon: { WIcon(name: "ic_check", size: 18, color: WT.textPrimary) }) {
                    send(.remove(id: timer.id))
                }
            }
        }
    }

    private var stopButton: some View {
        // 정지 = lucide square (DSKit에 없어 SF square.fill 폴백)
        actionButton("정지", tint: WT.stop,
                     icon: { Image(systemName: "square").font(.system(size: 17, weight: .bold)) }) {
            send(.remove(id: timer.id))
        }
    }

    private func actionButton<Icon: View>(
        _ title: String,
        tint: Color,
        filled: Bool = false,
        @ViewBuilder icon: () -> Icon,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            icon()
                .frame(width: 54, height: 38)
                .background(filled ? tint : WT.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(filled ? WT.textPrimary : tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // 명령 전송 후 목록으로 복귀 — 실제 상태는 폰이 보내는 다음 스냅샷으로 갱신된다.
    private func send(_ command: TimerWatchCommand) {
        connectivity.send(command: command)
        dismiss()
    }
}
