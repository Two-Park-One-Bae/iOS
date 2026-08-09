import Combine
import Foundation
import Domain

/*
 iOS 26.1 미만용 빈 스케줄러 (no-op).

 타이머는 26.1+ 전용 기능이다 — 무음·잠금·앱 종료를 모두 관통하는 시스템 알람(AlarmKit)이
 있어야 처치 시각을 보장할 수 있고, 그 이하에서 쓰던 로컬 알림 + 백그라운드 오디오 우회는
 보장이 되지 않아 걷어냈다. 26.1 미만에서는 타이머 탭이 안내 화면만 띄운다.

 그럼에도 이 구현체가 필요한 이유:
 SceneDelegate 가 버전과 무관하게 매 활성화마다 TimerUseCase 를 resolve 하고,
 그 생성자가 TimerAlarmScheduling 을 요구한다. 배포 타깃이 17.0 이라 그 미만에서
 AlarmKitAlarmScheduler() 를 만들 수 없으므로, 등록이 비면 실행 즉시 크래시한다.
 실제로 호출될 일은 없는 안전장치다.
 */
public final class UnavailableAlarmScheduler: TimerAlarmScheduling {

    public init() {}

    public func requestAuthorization() -> AnyPublisher<Bool, Never> {
        Just(false).eraseToAnyPublisher()
    }

    public func authorizationStatus() -> AnyPublisher<TimerAlarmAuthorizationStatus, Never> {
        Just(.denied).eraseToAnyPublisher()
    }

    public func scheduleAlarm(id: UUID, label: String, categoryName: String, body: String, fireDate: Date) {}

    public func cancelAlarm(id: UUID) {}
}
