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

/// 앱 밖(AlarmKit [완료] 인텐트, iOS 26.1+)에서 완료된 타이머 1건의 분석 페이로드.
public struct PendingWidgetTimerComplete: Codable, Sendable {
    public let category: String        // TimerCategory.displayName
    public let durationSec: Int
    public let completedAt: Date

    public init(category: String, durationSec: Int, completedAt: Date) {
        self.category = category
        self.durationSec = durationSec
        self.completedAt = completedAt
    }
}

/// App Group UserDefaults 기반 지연 분석 큐. 위젯이 append, 앱이 drain.
public enum WidgetAnalyticsQueue {

    // 앱·위젯·워치 공유 App Group (Data/TimerRepository.appGroupSuiteName 과 동일 값).
    private static let suiteName = "group.app.nursemate.care.timer"
    private static let startKey = "care.timer.pendingAnalytics"          // timer_start 큐
    private static let completeKey = "care.timer.pendingCompletes"       // timer_complete 큐

    private static var store: UserDefaults? { UserDefaults(suiteName: suiteName) }

    // MARK: - timer_start (위젯 백그라운드 시작)

    /// 위젯(백그라운드)에서 타이머 시작을 기록한다.
    public static func appendTimerStart(_ record: PendingWidgetTimerStart) {
        guard let store else { return }
        var list: [PendingWidgetTimerStart] = decode(store.data(forKey: startKey))
        list.append(record)
        if let data = try? JSONEncoder().encode(list) { store.set(data, forKey: startKey) }
    }

    /// 앱이 쌓인 시작 기록을 모두 읽고 큐를 비운다(발사 후 재발사 방지).
    public static func drainTimerStarts() -> [PendingWidgetTimerStart] {
        guard let store else { return [] }
        let list: [PendingWidgetTimerStart] = decode(store.data(forKey: startKey))
        store.removeObject(forKey: startKey)
        return list
    }

    // MARK: - timer_complete (앱 밖 AlarmKit [완료])

    /// 앱 밖 AlarmKit [완료] 인텐트에서 타이머 완료를 기록한다.
    public static func appendTimerComplete(_ record: PendingWidgetTimerComplete) {
        guard let store else { return }
        var list: [PendingWidgetTimerComplete] = decode(store.data(forKey: completeKey))
        list.append(record)
        if let data = try? JSONEncoder().encode(list) { store.set(data, forKey: completeKey) }
    }

    /// 앱이 쌓인 완료 기록을 모두 읽고 큐를 비운다.
    public static func drainTimerCompletes() -> [PendingWidgetTimerComplete] {
        guard let store else { return [] }
        let list: [PendingWidgetTimerComplete] = decode(store.data(forKey: completeKey))
        store.removeObject(forKey: completeKey)
        return list
    }

    private static func decode<T: Decodable>(_ data: Data?) -> [T] {
        guard let data, let list = try? JSONDecoder().decode([T].self, from: data) else { return [] }
        return list
    }
}
