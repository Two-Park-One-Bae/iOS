//
//  TimerLiveActivityWidget.swift
//  TimerWidget
//
//  Created by 바견규 on 7/7/26.
//
//  치료 타이머 Live Activity — 잠금화면 + Dynamic Island.
//  spec/design/DESIGN.pen `YNRPa` (타이머 / 시스템 표시) 기준.
//
//  - 진행 중: 링(파랑) + "AST · 검사" + 카운트다운(자동 갱신) + "외 N개 진행 중"
//  - 만료: 앰버 테두리 카드 + 벨 아이콘 + "종료 — 확인 필요"
//  - 카운트다운/링은 timerInterval 기반이라 푸시 없이 시스템이 자동 갱신.

import WidgetKit
import SwiftUI
import ActivityKit
import TimerShared

// MARK: - Widget

struct TimerLiveActivityWidget: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            // 잠금화면 / 배너 — isStale = 앱 프로세스 없이 endAt 도달(만료)한 경우
            TimerLockScreenView(state: context.state, isRinging: context.state.isRinging || context.isStale)
                .activityBackgroundTint(Color.timerCardBackground)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // 확장 (길게 누름)
                DynamicIslandExpandedRegion(.leading) {
                    if context.state.isRinging || context.isStale {
                        TimerExpiredRing(size: 44)
                            .padding(.leading, 4)
                    } else {
                        TimerRing(
                            startAt: context.state.startAt,
                            endAt: context.state.endAt,
                            size: 44
                        )
                        .padding(.leading, 4)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(context.state.label) · \(context.state.categoryName)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.timerLabelText)
                            .lineLimit(1)

                        if context.state.isRinging || context.isStale {
                            Text("종료")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color.timerAmber)
                                .lineLimit(1)
                        } else {
                            Text(
                                timerInterval: context.state.startAt...context.state.endAt,
                                countsDown: true
                            )
                            .font(.system(size: 22, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.timerBlue)
                            .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.othersCount > 0 {
                        Text("외 \(context.state.othersCount)개")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.timerGrayText)
                            .padding(.trailing, 4)
                    }
                }
            } compactLeading: {
                if context.state.isRinging || context.isStale {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.timerAmber)
                } else {
                    TimerRing(
                        startAt: context.state.startAt,
                        endAt: context.state.endAt,
                        size: 20
                    )
                }
            } compactTrailing: {
                if context.state.isRinging || context.isStale {
                    Text("종료")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.timerAmber)
                } else {
                    Text(
                        timerInterval: context.state.startAt...context.state.endAt,
                        countsDown: true
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.timerBlue)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 44)
                }
            } minimal: {
                if context.state.isRinging || context.isStale {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.timerAmber)
                } else {
                    TimerRing(
                        startAt: context.state.startAt,
                        endAt: context.state.endAt,
                        size: 20
                    )
                }
            }
            .keylineTint((context.state.isRinging || context.isStale) ? Color.timerAmber : Color.timerBlue)
        }
    }
}

// MARK: - 잠금화면 카드

private struct TimerLockScreenView: View {

    let state: TimerActivityAttributes.ContentState
    let isRinging: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Leading — 진행 링 또는 만료 벨 링
            if isRinging {
                TimerExpiredRing(size: 48)
            } else {
                TimerRing(startAt: state.startAt, endAt: state.endAt, size: 48)
            }

            // Center — 라벨 + 카운트다운/상태
            VStack(alignment: .leading, spacing: 2) {
                Text("\(state.label) · \(state.categoryName)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.timerLabelText)
                    .lineLimit(1)

                if isRinging {
                    Text("종료")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.timerAmber)
                        .lineLimit(1)
                } else {
                    Text(timerInterval: state.startAt...state.endAt, countsDown: true)
                        .font(.system(size: 26, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.timerBlue)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Trailing — 만료 시 00:00, 그리고 외 N개 진행 중
            VStack(alignment: .trailing, spacing: 4) {
                if isRinging {
                    Text("00:00")
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.timerAmber)
                        .fixedSize()
                }
                if state.othersCount > 0 {
                    Text("외 \(state.othersCount)개 진행 중")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.timerGrayText)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .padding(16)
    }
}

// MARK: - 진행 링 (timerInterval 기반 자동 갱신)

private struct TimerRing: View {

    let startAt: Date
    let endAt: Date
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.timerTrack, lineWidth: lineWidth)

            ProgressView(
                timerInterval: startAt...endAt,
                countsDown: true
            ) {
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

    private var lineWidth: CGFloat {
        max(2, size * 0.09)
    }
}

// MARK: - 만료 벨 링 (앰버 테두리 + 벨)

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

// MARK: - 색상 (디자인 시스템 미링크 — 위젯 타깃 자체 정의)

private extension Color {
    /// 진행 링·키라인·카운트다운 파랑 (#0EA5E9)
    static let timerBlue = Color(red: 0.055, green: 0.647, blue: 0.914)
    /// 만료 경고 앰버 (#F59E0B)
    static let timerAmber = Color(red: 0.961, green: 0.620, blue: 0.043)
    /// 라벨 텍스트 흰색 80% (#FFFFFFCC)
    static let timerLabelText = Color.white.opacity(0.80)
    /// 보조 텍스트 회색 (#94A3B8)
    static let timerGrayText = Color(red: 0.580, green: 0.639, blue: 0.722)
    /// 링 트랙 흰색 15% (#FFFFFF26)
    static let timerTrack = Color.white.opacity(0.15)
    /// LA 카드 배경 검정 (#000000)
    static let timerCardBackground = Color.black
}
