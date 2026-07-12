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
        TimerLiveActivityWidget()
        TimerPresetWidget()   // 잠금화면 프리셋 원탭 시작 (NM-302)
        if #available(iOS 26.0, *) {
            TimerAlarmCountdownWidget()
        }
    }
}
