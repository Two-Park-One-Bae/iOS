//
//  TimerWatchCommand.swift
//  TimerDomain — 워치→폰 명령 (NM-269)
//
//  spec/feature/care-timer/README.md "알람 예약은 항상 폰 단독" —
//  워치는 상태를 직접 바꾸지 않고 "명령"만 보낸다. 폰이 받아 UseCase로 실행하고
//  (알람 예약 포함) 전체 스냅샷을 다시 브로드캐스트한다. 폰·워치가 같은 타입을
//  링크해 명령 JSON도 100% 일치한다.

import Foundation

public enum TimerWatchCommand: Codable, Equatable, Sendable {
    case start(presetId: UUID)   // 프리셋 원탭 시작
    case pause(id: UUID)         // 일시정지
    case resume(id: UUID)        // 재개
    case snooze(id: UUID)        // 울림 [+5분]
    case remove(id: UUID)        // 완료 / 정지(취소) — 즉시 삭제
}

// MARK: - WCSession 전송 (폰·워치 공용)

public extension TimerWatchCommand {
    /// message·userInfo 딕셔너리의 페이로드 키. 스냅샷 키와 겹치지 않게 분리.
    static let wcCommandKey = "timerWatchCommand"

    /// WCSession(`sendMessage`·`transferUserInfo`)으로 보낼 딕셔너리.
    func wcPayload() throws -> [String: Any] {
        [Self.wcCommandKey: try JSONEncoder().encode(self)]
    }

    /// 수신 딕셔너리에서 명령 복원. 키가 없거나 형식이 어긋나면 nil.
    static func decode(fromWCPayload dict: [String: Any]) -> TimerWatchCommand? {
        guard let data = dict[wcCommandKey] as? Data else { return nil }
        return try? JSONDecoder().decode(TimerWatchCommand.self, from: data)
    }
}
