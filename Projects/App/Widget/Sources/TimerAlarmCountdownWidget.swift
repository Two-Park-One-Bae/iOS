import WidgetKit
import SwiftUI
import AlarmKit
import TimerShared

// AlarmKit 카운트다운 위젯 (iOS 26.1+ 경로) — 잠금화면 / Dynamic Island / StandBy.
// context.state(AlarmPresentationState)의 mode 로 진행/일시정지/만료를 구분해
// 커스텀 TimerLiveActivityWidget 과 같은 리프레시 디자인(DESIGN.pen r2jea·Km53q·s9CUwu)으로 그린다.
//  - 진행(countdown): 링 + "라벨 · 분류" + 카운트다운(blue, fireDate 기반 자동 갱신)
//  - 만료(alert / isStale): 앰버 벨 링 + "종료"
// AlarmKit 은 알람 1개당 LA 1개라 "외 N개 진행 중" 요약은 구조상 표시하지 않는다.
@available(iOS 26.0, *)
struct TimerAlarmCountdownWidget: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<CareTimerAlarmMetadata>.self) { context in
            AlarmLockScreenCard(info: AlarmDisplayInfo(context: context))
                .activityBackgroundTint(Color.timerCardBackground)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let info = AlarmDisplayInfo(context: context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    AlarmLeadingBadge(info: info, size: 44)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.timerLabelText)
                            .lineLimit(1)
                        AlarmPrimaryText(info: info, size: 22)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                AlarmLeadingBadge(info: info, size: 20)
            } compactTrailing: {
                AlarmCompactTrailing(info: info)
            } minimal: {
                AlarmLeadingBadge(info: info, size: 20)
            }
            .keylineTint(info.isRinging ? Color.timerAmber : Color.timerBlue)
        }
    }
}

// MARK: - 상태 해석 (AlarmPresentationState → 표시 모델)

@available(iOS 26.0, *)
private struct AlarmDisplayInfo {

    enum Phase {
        case running(start: Date, end: Date)
        case paused(remaining: Int)
        case ringing
    }

    let phase: Phase
    /// "라벨 · 분류" (분류 없으면 라벨만)
    let title: String

    var isRinging: Bool {
        if case .ringing = phase { return true }
        return false
    }

    init(context: ActivityViewContext<AlarmAttributes<CareTimerAlarmMetadata>>) {
        let meta = context.attributes.metadata
        let label = meta?.label ?? "타이머"
        let category = meta?.categoryName ?? ""
        title = category.isEmpty ? label : "\(label) · \(category)"

        switch context.state.mode {
        case .countdown(let cd):
            // isStale = 앱 없이 fireDate 도달 → 만료(울림)로 표시
            phase = context.isStale ? .ringing : .running(start: cd.startDate, end: cd.fireDate)
        case .paused(let p):
            let remaining = max(0, Int((p.totalCountdownDuration - p.previouslyElapsedDuration).rounded()))
            phase = .paused(remaining: remaining)
        case .alert:
            phase = .ringing
        }
    }
}

// MARK: - 잠금화면 카드

@available(iOS 26.0, *)
private struct AlarmLockScreenCard: View {

    let info: AlarmDisplayInfo

    var body: some View {
        HStack(spacing: 14) {
            AlarmLeadingBadge(info: info, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(info.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.timerLabelText)
                    .lineLimit(1)

                AlarmPrimaryText(info: info, size: 26)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }
}

// MARK: - Leading (링 / 일시정지 / 벨 링)

@available(iOS 26.0, *)
private struct AlarmLeadingBadge: View {

    let info: AlarmDisplayInfo
    let size: CGFloat

    var body: some View {
        switch info.phase {
        case .running(let start, let end):
            TimerRing(startAt: start, endAt: end, size: size)
        case .paused:
            BadgeCircle(systemName: "pause.fill", tint: Color.timerBlue, background: Color.timerTrack, size: size)
        case .ringing:
            TimerExpiredRing(size: size)
        }
    }
}

// MARK: - 주 텍스트 (카운트다운 / 남은시간 / 상태)

@available(iOS 26.0, *)
private struct AlarmPrimaryText: View {

    let info: AlarmDisplayInfo
    let size: CGFloat

    var body: some View {
        switch info.phase {
        case .running(let start, let end):
            Text(timerInterval: start...end, countsDown: true)
                .font(.system(size: size, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.timerBlue)
                .lineLimit(1)
        case .paused(let remaining):
            Text(clockString(remaining))
                .font(.system(size: size, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.timerBlue)
                .lineLimit(1)
        case .ringing:
            Text("종료")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.timerAmber)
                .lineLimit(1)
        }
    }
}

@available(iOS 26.0, *)
private struct AlarmCompactTrailing: View {

    let info: AlarmDisplayInfo

    var body: some View {
        switch info.phase {
        case .running(let start, let end):
            Text(timerInterval: start...end, countsDown: true)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.timerBlue)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 44)
        case .paused(let remaining):
            Text(clockString(remaining))
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.timerBlue)
        case .ringing:
            Text("종료")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.timerAmber)
        }
    }
}

// MARK: - 공용 뷰

/// 진행 링 (timerInterval 기반 자동 갱신)
private struct TimerRing: View {

    let startAt: Date
    let endAt: Date
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.timerTrack, lineWidth: max(2, size * 0.09))

            ProgressView(timerInterval: startAt...endAt, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
            .tint(Color.timerBlue)
            .labelsHidden()
        }
        .frame(width: size, height: size)
    }
}

/// 만료 벨 링 (앰버 테두리 + 벨)
private struct TimerExpiredRing: View {

    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.timerAmber, lineWidth: max(2, size * 0.09))

            Image(systemName: "bell.fill")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(Color.timerAmber)
        }
        .frame(width: size, height: size)
    }
}

/// 원형 아이콘 배지 (일시정지 등)
private struct BadgeCircle: View {

    let systemName: String
    let tint: Color
    let background: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(background)
            Image(systemName: systemName)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

private func clockString(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}

// MARK: - 색상 (디자인 시스템 미링크 — 위젯 타깃 자체 정의, DESIGN.pen 기준)

private extension Color {
    /// 진행 링·키라인·카운트다운 파랑 (#0EA5E9)
    static let timerBlue = Color(red: 0.055, green: 0.647, blue: 0.914)
    /// 만료 경고 앰버 (#F59E0B)
    static let timerAmber = Color(red: 0.961, green: 0.620, blue: 0.043)
    /// 라벨 텍스트 흰색 80% (#FFFFFFCC)
    static let timerLabelText = Color.white.opacity(0.80)
    /// 링 트랙 흰색 15% (#FFFFFF26)
    static let timerTrack = Color.white.opacity(0.15)
    /// LA 카드 배경 검정 (#000000)
    static let timerCardBackground = Color.black
}
