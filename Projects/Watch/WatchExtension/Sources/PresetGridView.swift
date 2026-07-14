import SwiftUI
import TimerDomain

// NM-303 컴플리케이션 목적지 — 프리셋 2열 그리드 (spec/design D7MpNK).
// 시계 페이스의 컴플리케이션 탭 → 앱 오픈 → 이 화면에서 전체 프리셋을 보고 원탭 시작.
struct PresetGridView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager

    /// 시작 직후 닫기(딥링크로 띄운 시트를 내림).
    let onStarted: () -> Void

    private var presets: [TimerPresetModel] {
        connectivity.snapshot?.presets ?? []
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        Group {
            if presets.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(presets) { preset in
                            Button {
                                connectivity.send(command: .start(presetId: preset.id))
                                onStarted()
                            } label: {
                                PresetGridCard(preset: preset)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    private var emptyState: some View {
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
    }
}

// 프리셋 카드 (D7MpNK "버튼 — AST") — 라벨 위 · 타이머+지속시간 아래(space-between).
struct PresetGridCard: View {
    let preset: TimerPresetModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(preset.label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 6)

            HStack(spacing: 5) {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .semibold))
                Text(WatchFormat.duration(preset.duration))
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(WT.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
