//
//  TimerUseCase.swift
//  Domain
//
//  Created by 바견규 on 7/7/26.
//
//  상태머신 (NM-258): 생성→RUNNING, RUNNING⇄PAUSED,
//  RUNNING→RINGING(endAt 도달), RINGING→[완료]삭제,
//  RUNNING·PAUSED→정지(취소) 삭제. 완료·취소는 이력 없이 즉시 삭제(MVP).

import Combine
import Foundation

/// 타이머 종료 사유 — 완료(끝까지 울림) vs 취소(울리기 전 정지).
public enum TimerEndReason: Sendable { case completed, cancelled }

/// 타이머 종료 1건의 도메인 신호 (분석 의존 없음 — 조립 계층이 이벤트로 번역).
public struct TimerEndInfo: Sendable {
    public let reason: TimerEndReason
    public let category: TimerCategory
    public let durationSec: Int
    public let elapsedSec: Int
    public let remainingSec: Int
}

public protocol TimerUseCase {
    // 타이머 — 생성은 프리셋 원탭뿐 (키워드 직접 입력 생성 없음)
    func start(preset: TimerPresetModel)
    func pause(id: UUID)
    func resume(id: UUID)
    /// ±시간 — endAt 이동 (C1 카드 +1분)
    func extend(id: UUID, by seconds: Int)
    /// [완료] 또는 정지(취소) — 즉시 삭제
    func remove(id: UUID)
    func updateMemo(id: UUID, memo: String?)
    /// RUNNING & endAt 도달 → RINGING 전이 (틱마다 호출)
    func refresh()
    /// 외부 프로세스(App Intent 등)가 App Group 저장소를 직접 바꾼 뒤 재동기화
    func reload()
    /// 워치에서 온 명령 실행 — 알람 예약은 폰 단독이라 워치는 명령만 보낸다(NM-269)
    func handleWatchCommand(_ command: TimerWatchCommand)

    // 프리셋 CRUD (폰 C3에서만)
    func addPreset(label: String, category: TimerCategory, duration: Int)
    func updatePreset(_ preset: TimerPresetModel)
    func deletePreset(id: UUID)

    // 알람 권한 — 첫 타이머 실행 직전 요청
    func requestAlarmPermission()
    func fetchAlarmPermission()

    var timers: CurrentValueSubject<[TreatmentTimerModel], Never> { get }
    var presets: CurrentValueSubject<[TimerPresetModel], Never> { get }
    var alarmPermission: PassthroughSubject<TimerAlarmAuthorizationStatus, Never> { get }
}

public final class DefaultTimerUseCase: TimerUseCase {

    private let repository: TimerRepositoryProtocol
    private let alarmScheduler: TimerAlarmScheduling
    private let watchSync: TimerWatchSyncing?
    private var cancellables = Set<AnyCancellable>()
    /// 폰의 알람 권한 승인 여부 캐시(NM-360) — 워치 스냅샷에 실어 시작 게이트에 쓴다.
    /// init 에서 영속 플래그로 시드하고, 권한 확인/요청 때 갱신한다. nil=아직 물어본 적 없음.
    private var alarmAuthorizedCache: Bool?

    public let timers = CurrentValueSubject<[TreatmentTimerModel], Never>([])
    public let presets = CurrentValueSubject<[TimerPresetModel], Never>([])
    public let alarmPermission = PassthroughSubject<TimerAlarmAuthorizationStatus, Never>()
    /// 타이머 종료(완료/취소) 신호 — Core(분석) 의존 없이 순수 도메인 이벤트만 방출.
    /// 조립 계층(RegisterDependencies)이 구독해 timer_complete/timer_cancel 로 번역한다.
    public let timerEnded = PassthroughSubject<TimerEndInfo, Never>()
    /// 알람 권한 프롬프트 응답(true=granted) — 조립 계층이 permission_result 로 번역.
    public let alarmPermissionPrompted = PassthroughSubject<Bool, Never>()

    public init(
        repository: TimerRepositoryProtocol,
        alarmScheduler: TimerAlarmScheduling,
        watchSync: TimerWatchSyncing? = nil
    ) {
        self.repository = repository
        self.alarmScheduler = alarmScheduler
        self.watchSync = watchSync
        self.alarmAuthorizedCache = repository.alarmAuthorizedFlag()  // 지난 세션에 기록된 승인 여부로 시드
        timers.send(repository.loadTimers())
        presets.send(repository.loadPresets())

        // 타이머·프리셋이 바뀔 때마다 워치로 전체 스냅샷 push. 구독 시 현재값이 즉시 흘러
        // 앱 시작 직후에도 최신 상태를 한 번 보낸다(updateApplicationContext는 병합됨).
        if let watchSync {
            Publishers.CombineLatest(timers, presets)
                .sink { [weak self] timers, presets in
                    watchSync.sync(timers: timers, presets: presets, alarmAuthorized: self?.alarmAuthorizedCache)
                }
                .store(in: &cancellables)
        }
    }

    // MARK: - Timers

    public func start(preset: TimerPresetModel) {
        // 실행 = 복사: 이후 프리셋을 고쳐도 도는 타이머는 영향 없음
        let endAt = Date().addingTimeInterval(TimeInterval(preset.duration))
        let timer = TreatmentTimerModel(
            label: preset.label,
            category: preset.category,
            duration: preset.duration,
            endAt: endAt,
            state: .running
        )
        mutate { $0.append(timer) }
        alarmScheduler.scheduleAlarm(id: timer.id, label: timer.label, categoryName: timer.category.displayName, body: alarmBody(duration: timer.duration), fireDate: endAt)
    }

    public func pause(id: UUID) {
        mutate { list in
            guard let i = list.firstIndex(where: { $0.id == id }), list[i].state == .running else { return }
            list[i].remaining = list[i].remainingSeconds()
            list[i].state = .paused
        }
        alarmScheduler.cancelAlarm(id: id)
    }

    public func resume(id: UUID) {
        var scheduled: (label: String, categoryName: String, body: String, endAt: Date)?
        mutate { list in
            guard let i = list.firstIndex(where: { $0.id == id }), list[i].state == .paused else { return }
            let endAt = Date().addingTimeInterval(TimeInterval(list[i].remaining ?? 0))
            list[i].endAt = endAt
            list[i].remaining = nil
            list[i].state = .running
            scheduled = (list[i].label, list[i].category.displayName, alarmBody(duration: list[i].duration), endAt)
        }
        if let scheduled {
            alarmScheduler.scheduleAlarm(id: id, label: scheduled.label, categoryName: scheduled.categoryName, body: scheduled.body, fireDate: scheduled.endAt)
        }
    }

    public func extend(id: UUID, by seconds: Int) {
        var scheduled: (label: String, categoryName: String, body: String, endAt: Date)?
        mutate { list in
            guard let i = list.firstIndex(where: { $0.id == id }) else { return }
            switch list[i].state {
            case .running:
                list[i].endAt = list[i].endAt.addingTimeInterval(TimeInterval(seconds))
                scheduled = (list[i].label, list[i].category.displayName, alarmBody(duration: list[i].duration), list[i].endAt)
            case .paused:
                list[i].remaining = max(0, (list[i].remaining ?? 0) + seconds)
            case .ringing:
                break // 울림 중엔 시간 조정 불가 ([완료]로만 종료)
            }
        }
        if let scheduled {
            alarmScheduler.scheduleAlarm(id: id, label: scheduled.label, categoryName: scheduled.categoryName, body: scheduled.body, fireDate: scheduled.endAt)
        }
    }

    public func remove(id: UUID) {
        // 완료/취소 신호 방출 — 삭제 전 상태로 구분(.ringing 또는 endAt 경과 = 완료).
        if let t = timers.value.first(where: { $0.id == id }) {
            let remaining = max(0, t.remainingSeconds())
            let completed = t.state == .ringing || remaining == 0
            timerEnded.send(TimerEndInfo(
                reason: completed ? .completed : .cancelled,
                category: t.category,
                durationSec: t.duration,
                elapsedSec: max(0, t.duration - remaining),
                remainingSec: remaining
            ))
        }
        mutate { $0.removeAll { $0.id == id } }
        alarmScheduler.cancelAlarm(id: id)
    }

    public func updateMemo(id: UUID, memo: String?) {
        mutate { list in
            guard let i = list.firstIndex(where: { $0.id == id }) else { return }
            list[i].memo = memo?.isEmpty == true ? nil : memo
        }
    }

    public func refresh() {
        var changed = false
        var list = timers.value
        for i in list.indices where list[i].state == .running && list[i].remainingSeconds() == 0 {
            list[i].state = .ringing
            changed = true
        }
        if changed {
            repository.saveTimers(list)
            timers.send(list)
        }
    }

    public func reload() {
        timers.send(repository.loadTimers())
    }

    public func handleWatchCommand(_ command: TimerWatchCommand) {
        switch command {
        case .start(let presetId):
            guard let preset = presets.value.first(where: { $0.id == presetId }) else { return }
            start(preset: preset)
        case .pause(let id):  pause(id: id)
        case .resume(let id): resume(id: id)
        case .remove(let id): remove(id: id)
        }
    }

    // MARK: - Presets

    public func addPreset(label: String, category: TimerCategory, duration: Int) {
        var list = presets.value
        list.append(TimerPresetModel(label: label, category: category, duration: duration))
        repository.savePresets(list)
        presets.send(list)
    }

    public func updatePreset(_ preset: TimerPresetModel) {
        var list = presets.value
        guard let i = list.firstIndex(where: { $0.id == preset.id }) else { return }
        list[i] = preset
        repository.savePresets(list)
        presets.send(list)
    }

    public func deletePreset(id: UUID) {
        var list = presets.value
        list.removeAll { $0.id == id }
        repository.savePresets(list)
        presets.send(list)
    }

    // MARK: - Alarm Permission

    public func requestAlarmPermission() {
        alarmScheduler.requestAuthorization()
            .map { $0 ? TimerAlarmAuthorizationStatus.authorized : .denied }
            .sink { [weak self] status in
                self?.updateAlarmAuthorized(status == .authorized)
                self?.alarmPermissionPrompted.send(status == .authorized)  // 프롬프트 응답만
                self?.alarmPermission.send(status)
            }
            .store(in: &cancellables)
    }

    public func fetchAlarmPermission() {
        alarmScheduler.authorizationStatus()
            .sink { [weak self] status in
                self?.updateAlarmAuthorized(status == .authorized)
                self?.alarmPermission.send(status)
            }
            .store(in: &cancellables)
    }

    // 승인 여부를 App Group(위젯용)·캐시(워치용)에 반영하고, 워치에 즉시 재동기화(NM-360).
    // 타이머 변경이 없어도 권한만 바뀌면 워치가 알아야 시작 게이트가 최신이 된다.
    private func updateAlarmAuthorized(_ authorized: Bool) {
        repository.setAlarmAuthorized(authorized)
        alarmAuthorizedCache = authorized
        watchSync?.sync(timers: timers.value, presets: presets.value, alarmAuthorized: authorized)
    }

    // MARK: - Private

    private func mutate(_ transform: (inout [TreatmentTimerModel]) -> Void) {
        var list = timers.value
        transform(&list)
        repository.saveTimers(list)
        timers.send(list)
    }

    /// 종료 알림 본문 — "15분 타이머가 끝났어요" (디자인 '시스템 알람' wrEli·ZFXjS).
    private func alarmBody(duration seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h)시간") }
        if m > 0 { parts.append("\(m)분") }
        if s > 0 { parts.append("\(s)초") }
        let duration = parts.isEmpty ? "0초" : parts.joined(separator: " ")
        return "\(duration) 타이머가 끝났어요"
    }
}
