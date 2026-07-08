//
//  TimerLiveActivityManager.swift
//  App
//
//  Created by 바견규 on 7/7/26.
//
//  잠금화면 실시간 표시 (spec): 진행 중 타이머는 앱 밖에서 요약 1개만 —
//  가장 임박한 타이머(링+키워드·분류+카운트다운) + "외 N개 진행 중".
//  만료 시 "종료 — 확인 필요"(warning)로 전환, 알람을 놓쳐도 흔적이 남는다.

import ActivityKit
import Combine
import Foundation
import Core
import Domain
import TimerShared

public final class TimerLiveActivityManager {

    public static let shared = TimerLiveActivityManager()

    private var activity: Activity<TimerActivityAttributes>?
    private var cancellables = Set<AnyCancellable>()

    public func activate() {
        // 앱이 종료됐다 다시 켜지면 self.activity 는 nil 이라, sync 가 이미 잠금화면에 떠 있는
        // Activity 를 못 보고 새로 하나 더 만든다 → 중복/유령 카드. 먼저 재획득하고 중복은 정리.
        reattachExistingActivity()

        let useCase = DIContainer.shared.resolve(TimerUseCase.self)
        useCase.timers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timers in
                self?.sync(timers)
            }
            .store(in: &cancellables)
    }

    /// 재시작 시 살아있는 Live Activity 재획득 — 하나만 유지하고 나머지는 종료.
    private func reattachExistingActivity() {
        let existing = Activity<TimerActivityAttributes>.activities
        activity = existing.first
        for extra in existing.dropFirst() {
            Task { await extra.end(nil, dismissalPolicy: .immediate) }
        }
    }

    // MARK: - Sync

    private func sync(_ timers: [TreatmentTimerModel]) {
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        guard enabled else { return }

        // 표시 대상: RINGING 우선(확인 필요), 없으면 가장 임박한 RUNNING.
        // PAUSED만 있으면 표시하지 않는다.
        let ringing = timers.filter { $0.state == .ringing }.min { $0.endAt < $1.endAt }
        let running = timers.filter { $0.state == .running }.min { $0.endAt < $1.endAt }
        guard let target = ringing ?? running else {
            end()
            return
        }

        let active = timers.filter { $0.state == .running || $0.state == .ringing }
        let state = TimerActivityAttributes.ContentState(
            label: target.label,
            categoryName: target.category.liveActivityName,
            startAt: target.endAt.addingTimeInterval(-TimeInterval(target.duration)),
            endAt: target.endAt,
            isRinging: target.state == .ringing,
            othersCount: max(0, active.count - 1)
        )

        // staleDate = endAt: 만료 시각에 시스템이 위젯을 재렌더(context.isStale)
        // → 앱 프로세스 없이도 "종료 — 확인 필요"로 전환된다
        let staleDate: Date? = target.state == .ringing ? nil : target.endAt
        let content = ActivityContent(state: state, staleDate: staleDate)

        if let activity {
            Task { await activity.update(content) }
        } else {
            do {
                activity = try Activity.request(
                    attributes: TimerActivityAttributes(),
                    content: content
                )
            } catch {
            }
        }
    }

    private func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}

private extension TimerCategory {
    var liveActivityName: String {
        switch self {
        case .medication:  return "투약"
        case .treatment:   return "처치"
        case .examination: return "검사"
        }
    }
}
