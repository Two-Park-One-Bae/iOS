//
//  WidgetAnalyticsQueue.swift
//  TimerDomain — 폰(iOS)·위젯 공용
//
//  위젯 확장(별도 프로세스)이 앱을 안 열고 시작한 타이머를, 앱이 다음 활성화 때
//  집계하도록 App Group UserDefaults 에 쌓아두는 지연 분석 큐.
//
//  배경: iOS 26.1+ & 알람 승인 시 위젯 버튼은 StartPresetTimerIntent(백그라운드)로
//  타이머를 시작한다. 이때 앱 프로세스는 뜨지 않고, 위젯 타깃은 Firebase 를 링크하지
//  않으므로 timer_start 이벤트가 유실된다. → 위젯이 여기 append, SceneDelegate 가 drain.
//

import Foundation

/// 위젯에서 백그라운드 시작된 타이머 1건의 분석 페이로드.
public struct PendingWidgetTimerStart: Codable, Sendable {
    public let presetLabel: String
    public let category: String        // TimerCategory.displayName
    public let durationSec: Int
    public let startedAt: Date

    public init(presetLabel: String, category: String, durationSec: Int, startedAt: Date) {
        self.presetLabel = presetLabel
        self.category = category
        self.durationSec = durationSec
        self.startedAt = startedAt
    }
}

/// App Group UserDefaults 기반 지연 분석 큐. 위젯이 append, 앱이 drain.
public enum WidgetAnalyticsQueue {

    // 앱·위젯·워치 공유 App Group (Data/TimerRepository.appGroupSuiteName 과 동일 값).
    private static let suiteName = "group.app.nursemate.timer"
    private static let key = "care.timer.pendingAnalytics"

    private static var store: UserDefaults? { UserDefaults(suiteName: suiteName) }

    /// 위젯(백그라운드)에서 타이머 시작을 기록한다.
    public static func appendTimerStart(_ record: PendingWidgetTimerStart) {
        guard let store else { return }
        var list = load(from: store)
        list.append(record)
        if let data = try? JSONEncoder().encode(list) {
            store.set(data, forKey: key)
        }
    }

    /// 앱이 쌓인 기록을 모두 읽고 큐를 비운다(발사 후 재발사 방지).
    public static func drainTimerStarts() -> [PendingWidgetTimerStart] {
        guard let store else { return [] }
        let list = load(from: store)
        store.removeObject(forKey: key)
        return list
    }

    private static func load(from store: UserDefaults) -> [PendingWidgetTimerStart] {
        guard let data = store.data(forKey: key),
              let list = try? JSONDecoder().decode([PendingWidgetTimerStart].self, from: data)
        else { return [] }
        return list
    }
}
