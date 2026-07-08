import SwiftUI
import TimerDomain

// W2/W3 조작 — 카드 탭으로 진입(spec/feature/care-timer/README.md).
// 실행: 일시정지/정지 · 일시정지됨: 재개/정지 · 울림: 완료/+5분.
// 모든 조작은 명령으로 폰에 전달 — 폰이 실행·알람 처리 후 스냅샷 재전송.
struct TimerActionView: View {
    let timer: TreatmentTimerModel

    @EnvironmentObject var connectivity: WatchConnectivityManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(timer.category.displayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(timer.label)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                switch timer.state {
                case .running:
                    actionButton("일시정지", systemImage: "pause.fill", tint: .orange) {
                        send(.pause(id: timer.id))
                    }
                    stopButton
                case .paused:
                    actionButton("재개", systemImage: "play.fill", tint: .blue) {
                        send(.resume(id: timer.id))
                    }
                    stopButton
                case .ringing:
                    actionButton("완료", systemImage: "checkmark", tint: .green) {
                        send(.remove(id: timer.id))
                    }
                    actionButton("+5분", systemImage: "plus", tint: .blue) {
                        send(.snooze(id: timer.id))
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("타이머")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var stopButton: some View {
        actionButton("정지", systemImage: "xmark", tint: .red) {
            send(.remove(id: timer.id))
        }
    }

    private func actionButton(
        _ title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .tint(tint)
    }

    // 명령 전송 후 목록으로 복귀 — 실제 상태는 폰이 보내는 다음 스냅샷으로 갱신된다.
    private func send(_ command: TimerWatchCommand) {
        connectivity.send(command: command)
        dismiss()
    }
}
