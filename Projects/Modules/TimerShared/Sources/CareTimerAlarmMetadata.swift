//
//  CareTimerAlarmMetadata.swift
//  TimerShared — TimerFeature / TimerWidget 공용
//
//  Created by 바견규 on 7/7/26.
//
//  AlarmKit 알람의 메타데이터 — 카운트다운/알림 UI에 표시할 타이머 정보.
//  AlarmAttributes<CareTimerAlarmMetadata> 의 Metadata 로 사용. App + Widget 양쪽이
//  같은 타입을 쓰도록 공유 모듈에 배치. AlarmMetadata 프로토콜(AlarmKit, iOS 26) 준수.

import Foundation
import AlarmKit

@available(iOS 26.0, *)
public struct CareTimerAlarmMetadata: AlarmMetadata {
    /// 처치 키워드 (예: "AST")
    public let label: String
    /// 분류 표시명 (투약/처치/검사)
    public let categoryName: String
    /// 전체 초 — 진행률·본문 표시용
    public let duration: Int

    public init(label: String, categoryName: String, duration: Int) {
        self.label = label
        self.categoryName = categoryName
        self.duration = duration
    }
}
