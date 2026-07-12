import SwiftUI
import Domain

// 런처 위젯 진입 — 전체 프리셋 중 하나를 골라 타이머 시작 (NM-302).
struct TimerQuickStartPickerView: View {
    let presets: [TimerPresetModel]
    let onStart: (TimerPresetModel) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if presets.isEmpty {
                    ContentUnavailableView("프리셋이 없어요", systemImage: "timer")
                } else {
                    List(presets) { preset in
                        Button {
                            onStart(preset)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "play.circle.fill").foregroundStyle(.blue)
                                Text(preset.label)
                                Spacer()
                                Text(durationText(preset.duration)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("타이머 시작")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
            }
        }
    }

    private func durationText(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h)시간") }
        if m > 0 { parts.append("\(m)분") }
        if s > 0 { parts.append("\(s)초") }
        return parts.isEmpty ? "0초" : parts.joined(separator: " ")
    }
}
