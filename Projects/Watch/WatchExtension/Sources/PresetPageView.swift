import SwiftUI
import TimerDomain

// W1 프리셋 페이지 — 프리셋 원탭 시작(spec/feature/care-timer/README.md).
// 목록·순서는 폰에서 받은 스냅샷을 따른다. 원탭 시작(write-back)은 후속.
struct PresetPageView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager

    private var presets: [TimerPresetModel] {
        connectivity.snapshot?.presets ?? []
    }

    var body: some View {
        Group {
            if presets.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("프리셋 없음")
                        .font(.headline)
                    Text("폰에서 프리셋을 추가하세요")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding()
            } else {
                List {
                    Section {
                        ForEach(presets) { preset in
                            PresetRow(preset: preset)
                        }
                    } header: {
                        Text("누르면 바로 시작됩니다")
                    }
                }
            }
        }
        .navigationTitle("프리셋")
    }
}

// 프리셋 행 — 재생 아이콘 + 라벨 + 지속시간.
struct PresetRow: View {
    let preset: TimerPresetModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.circle.fill")
                .foregroundStyle(.blue)
            Text(preset.label)
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(Self.durationText(preset.duration))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // 폰 TimerFormat.duration 과 동일 표기: 900→"15분", 7200→"2시간", 5400→"1시간 30분".
    static func durationText(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h)시간") }
        if m > 0 { parts.append("\(m)분") }
        if s > 0 { parts.append("\(s)초") }
        return parts.isEmpty ? "0초" : parts.joined(separator: " ")
    }
}
