import SwiftUI
import TimerDomain

// 진행중 리스트의 카드 한 장. 처치 키워드 + 분류 태그 + 남은 시간만 노출.
struct TimerCardRow: View {
    let timer: TreatmentTimerModel
    let now: Date

    private var isRinging: Bool { timer.state == .ringing }
    private var isPaused: Bool { timer.state == .paused }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                categoryTag
                Spacer(minLength: 0)
                if isPaused {
                    Image(systemName: "pause.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(timer.label)
                .font(.headline)
                .lineLimit(1)

            Text(timeText)
                .font(.system(.title3, design: .rounded).monospacedDigit())
                .foregroundStyle(isRinging ? Color.white : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isRinging ? Color.orange : Color.gray.opacity(0.18))
        )
    }

    private var categoryTag: some View {
        Text(timer.category.displayName)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill((isRinging ? Color.white : categoryColor).opacity(0.22))
            )
            .foregroundStyle(isRinging ? Color.white : categoryColor)
    }

    // 폰 C1 태그 색 컨벤션 근사: 투약=파랑 / 처치=청록 / 검사=남색.
    private var categoryColor: Color {
        switch timer.category {
        case .medication:  return .blue
        case .treatment:   return .teal
        case .examination: return .indigo
        }
    }

    // 카운트다운 포맷 — 폰 TimerFormat.countdown 과 동일(mm:ss / h:mm:ss).
    private var timeText: String {
        guard !isRinging else { return "종료" }
        let secs = timer.remainingSeconds(at: now)
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
