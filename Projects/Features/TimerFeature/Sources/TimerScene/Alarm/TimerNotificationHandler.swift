//
//  TimerNotificationHandler.swift
//  App
//
//  Created by 바견규 on 7/7/26.
//
//  시스템 알람 액션 처리 (NM-259): [완료] = 타이머 삭제 + 알람 끔,
//  [+5분] = 지금부터 5분 재실행. 알람 확인·탭 후 랜딩 = C1(타이머 탭).

import UIKit
import UserNotifications
import Core
import Domain
import Data

extension Notification.Name {
    /// 알람 탭 → C1 타이머 탭 랜딩 (App 이 관찰, TimerFeature 가 발신하는 공용 계약)
    public static let openTimerTab = Notification.Name("openTimerTab")
}

public final class TimerNotificationHandler: NSObject, UNUserNotificationCenterDelegate {

    public static let shared = TimerNotificationHandler()

    public func activate() {
        UNUserNotificationCenter.current().delegate = self
    }

    // 포그라운드 만료는 풀스크린 알람(TimerRingingAlarmPresenter)이 시각+루핑 사운드를
    // 담당하므로, 여기서는 시스템 배너/사운드를 억제한다 (알림센터 기록만 남김).
    // 백그라운드/잠금화면에서는 시스템이 기본 알림을 렌더링한다.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.list])
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard let id = UUID(uuidString: response.notification.request.identifier) else { return }

        let useCase = DIContainer.shared.resolve(TimerUseCase.self)
        // 알림 발화 시점의 RINGING 전이를 먼저 반영
        useCase.refresh()

        switch response.actionIdentifier {
        case TimerAlarmScheduler.Action.complete:
            useCase.remove(id: id)
        case TimerAlarmScheduler.Action.snooze:
            useCase.snooze(id: id)
        case UNNotificationDefaultActionIdentifier:
            // 알림 본문 탭 → 앱 열고 C1 랜딩
            NotificationCenter.default.post(name: .openTimerTab, object: nil)
        default:
            break
        }
    }
}
