//
//  TimerActivityAttributes.swift
//  TimerShared — TimerFeature / TimerWidget 공용
//
//  Created by 바견규 on 7/7/26.
//
//  잠금화면 Live Activity·Dynamic Island 계약 (spec: 요약 1개만 —
//  가장 임박한 타이머 + "외 N개 진행 중", 만료 시 "종료 — 확인 필요").
//  프라이버시 규칙: 처치 키워드 + 분류 태그만 노출.

import ActivityKit
import Foundation

public struct TimerActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        /// 처치 키워드 (예: "AST")
        public var label: String
        /// 분류 표시명 (투약/처치/검사)
        public var categoryName: String
        /// 타이머 전체 구간 — 링/카운트다운 자동 갱신용
        public var startAt: Date
        public var endAt: Date
        /// 만료(울림) 여부 — true면 "종료 — 확인 필요" warning 표시
        public var isRinging: Bool
        /// 요약 대상 외 진행 중 개수
        public var othersCount: Int

        public init(
            label: String,
            categoryName: String,
            startAt: Date,
            endAt: Date,
            isRinging: Bool,
            othersCount: Int
        ) {
            self.label = label
            self.categoryName = categoryName
            self.startAt = startAt
            self.endAt = endAt
            self.isRinging = isRinging
            self.othersCount = othersCount
        }
    }

    public init() {}
}
