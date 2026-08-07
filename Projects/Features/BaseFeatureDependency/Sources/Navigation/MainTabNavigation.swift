import Foundation

// 홈 등에서 탭바 전환을 요청하는 알림 (뷰 push 대신 탭 이동). App(AppCoordinator)이 관찰해 처리.
public extension Notification.Name {
    /// 약물 식별 → 알약 탭으로 이동
    static let selectPillTab = Notification.Name("app.selectPillTab")
    /// 처치 타이머 → 타이머 탭으로 이동
    static let selectTimerTab = Notification.Name("app.selectTimerTab")
    /// 홈 탭으로 이동 (예: 촬영 취소 후 복귀)
    static let selectHomeTab = Notification.Name("app.selectHomeTab")
    /// 알약 탭이 실제로 선택됨 → 약물 식별 카메라 present 트리거
    static let pillTabSelected = Notification.Name("app.pillTabSelected")
    /// 위젯 딥링크 랜딩 → 타이머 탭으로 이동.
    /// (커스텀 알람 스택을 걷어내면서 TimerNotificationHandler 에 있던 정의를 여기로 옮김)
    static let openTimerTab = Notification.Name("openTimerTab")
}
