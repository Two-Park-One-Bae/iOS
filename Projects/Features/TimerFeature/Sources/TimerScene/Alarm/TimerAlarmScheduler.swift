//
//  TimerAlarmScheduler.swift
//  Data
//
//  Created by 바견규 on 7/7/26.
//
//  UNUserNotificationCenter 기반 로컬 알람.
//  잠금화면/사용중 알럿은 시스템이 렌더링 (디자인 '시스템 알람' 화면 = 예상 화면).
//  표기(NM-259): title = "{라벨} 종료", 버튼 = [완료] / [+5분].

import Combine
import Foundation
import UserNotifications
import Domain

public final class TimerAlarmScheduler: TimerAlarmScheduling {

    public enum Action {
        public static let category = "CARE_TIMER_ALARM"
        public static let complete = "CARE_TIMER_COMPLETE"
        public static let snooze = "CARE_TIMER_SNOOZE"
    }

    private let center = UNUserNotificationCenter.current()

    public init() {
        registerCategory()
    }

    public func requestAuthorization() -> AnyPublisher<Bool, Never> {
        Future { [center] promise in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                promise(.success(granted))
            }
        }
        .eraseToAnyPublisher()
    }

    public func authorizationStatus() -> AnyPublisher<TimerAlarmAuthorizationStatus, Never> {
        Future { [center] promise in
            center.getNotificationSettings { settings in
                switch settings.authorizationStatus {
                case .notDetermined:
                    promise(.success(.notDetermined))
                case .authorized, .provisional, .ephemeral:
                    promise(.success(.authorized))
                default:
                    promise(.success(.denied))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    public func scheduleAlarm(id: UUID, label: String, categoryName: String, body: String, fireDate: Date) {
        cancelAlarm(id: id)
        let content = UNMutableNotificationContent()
        content.title = "\(label) 종료"
        content.body = body
        // .defaultCritical은 Critical Alerts entitlement(별도 승인) 없이는 무시됨 — 기본 사운드 사용
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = Action.category

        let interval = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: id.uuidString, content: content, trigger: trigger))
    }

    public func cancelAlarm(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        center.removeDeliveredNotifications(withIdentifiers: [id.uuidString])
    }

    // MARK: - Private

    private func registerCategory() {
        let complete = UNNotificationAction(identifier: Action.complete, title: "완료", options: [])
        let snooze = UNNotificationAction(identifier: Action.snooze, title: "+5분", options: [])
        let category = UNNotificationCategory(
            identifier: Action.category,
            actions: [complete, snooze],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }
}
