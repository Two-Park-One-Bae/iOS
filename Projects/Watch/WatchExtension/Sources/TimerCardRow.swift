import SwiftUI
import TimerDomain

// 진행중 카드 (RUNNING/PAUSED) — 진행률 링 + 라벨/분류 + 남은 시간 + chevron.
// spec/design OduYy. 크기는 고정 대신 시스템 폰트·비율·minimumScaleFactor 로 적응.
struct TimerCardRow: View {
    let timer: TreatmentTimerModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = timer.remainingSeconds(at: context.date)
            let progress = timer.duration > 0 ? Double(remaining) / Double(timer.duration) : 0
            let paused = timer.state == .paused

            HStack(spacing: 9) {
                // 링: 화면 폭 비율(디자인 60/396 ≈ 15%)로 적응.
                ProgressRing(progress: progress,
                             tint: paused ? WT.muted : WT.accent,
                             lineWidth: 4, paused: paused)
                    .containerRelativeFrame(.horizontal) { w, _ in w * 0.17 }
                    .aspectRatio(1, contentMode: .fit)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(timer.label)
                            .font(.headline)
                            .foregroundStyle(WT.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .layoutPriority(1)
                        Text(timer.category.displayName)
                            .font(.caption2)
                            .foregroundStyle(WT.category(timer.category))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    Text(paused ? "\(WatchFormat.countdown(remaining)) · 일시정지"
                                : WatchFormat.countdown(remaining))
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(paused ? WT.muted : WT.remaining)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                WIcon(name: "ic_chevron_right", size: 13, color: WT.muted)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(WT.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

// 만료 카드 (RINGING) — 경고색 배경 + 종 + 라벨/분류 + [완료]. spec/design OduYy "만료 카드".
struct RingingCardRow: View {
    let timer: TreatmentTimerModel
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                WIcon(name: "ic_bell", size: 15, color: WT.bell)
                Text(timer.label)
                    .font(.headline)
                    .foregroundStyle(WT.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(timer.category.displayName)
                    .font(.caption2)
                    .foregroundStyle(WT.category(timer.category))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            Button(action: onComplete) {
                Text("완료")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(WT.ringingAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(WT.textPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(WT.ringingBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(WT.ringingAccent, lineWidth: 1.5)
        )
    }
}
