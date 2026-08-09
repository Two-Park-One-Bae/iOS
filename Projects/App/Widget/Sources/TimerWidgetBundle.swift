//
//  TimerWidgetBundle.swift
//  TimerWidget
//
//  Created by 바견규 on 7/7/26.
//
//  위젯 익스텐션 진입점 — 치료 타이머 Live Activity 번들.

import WidgetKit
import SwiftUI

@main
struct TimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        // 커스텀 Live Activity(TimerLiveActivityWidget)는 제거됨 —
        // 타이머가 26.1+ 전용이 되면서 AlarmKit 카운트다운(TimerAlarmCountdownWidget)이 대체한다.
        TimerPresetWidget()      // 잠금화면 설정형 프리셋 위젯 (NM-302)
        TimerQuickStartWidget()  // 잠금화면 런처 — 탭해서 전체 중 골라 시작 (NM-302)
        if #available(iOS 26.0, *) {
            TimerAlarmCountdownWidget()
        }
    }
}
