import SwiftUI
import TimerDomain

// W1 프리셋 페이지 (spec/design mngll) — 프리셋 원탭 시작.
// List 네이티브 사이징으로 워치 크기에 자동 적응. 탭 → start 명령 → 활성 페이지 전환.
struct PresetPageView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager

    /// 프리셋 시작 직후 호출 — 활성 페이지로 전환(ContentView가 소유).
    let onStarted: () -> Void

    private var presets: [TimerPresetModel] {
        connectivity.snapshot?.presets ?? []
    }

    var body: some View {
        Group {
            if presets.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.title2)
                        .foregroundStyle(WT.muted)
                    Text("프리셋 없음")
                        .font(.headline)
                        .foregroundStyle(WT.textPrimary)
                    Text("폰에서 프리셋을 추가하세요")
                        .font(.caption2)
                        .foregroundStyle(WT.muted)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                // List 대신 ScrollView+VStack — 카드 간격을 직접(정확히) 제어.
                ScrollView {
                    VStack(spacing: 6) {
                        Text("누르면 바로 시작됩니다")
                            .font(.caption2)
                            .foregroundStyle(WT.muted)
                            .frame(maxWidth: .infinity)

                        ForEach(presets) { preset in
                            Button {
                                connectivity.send(command: .start(presetId: preset.id))
                                onStarted()
                            } label: {
                                PresetRow(preset: preset)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, -12)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// 프리셋 카드 (spec/design "프리셋 — AST") — 재생 아이콘 + 라벨 + 지속시간.
struct PresetRow: View {
    let preset: TimerPresetModel

    var body: some View {
        HStack(spacing: 9) {
            // circle-play = 원(외곽선) + lucide ic_play 에셋. 아이콘은 작게.
            ZStack {
                Circle().stroke(WT.accent, lineWidth: 1.3).frame(width: 16, height: 16)
                WIcon(name: "ic_play", size: 8, color: WT.accent)
                    .offset(x: 1)
            }
            // 라벨: 길어도 잘리지 않고 축소해서 전부 보이게.
            Text(preset.label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(WT.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .layoutPriority(1)
            Spacer(minLength: 4)
            Text(WatchFormat.duration(preset.duration))
                .font(.system(size: 13))
                .foregroundStyle(WT.muted)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(WT.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
