//
//  TimerUseCase.swift
//  Domain
//
//  Created by 바견규 on 7/7/26.
//
//  상태머신 (NM-258): 생성→RUNNING, RUNNING⇄PAUSED,
//  RUNNING→RINGING(endAt 도달), RINGING→[완료]삭제 / [+5분]RUNNING,
//  RUNNING·PAUSED→정지(취소) 삭제. 완료·취소는 이력 없이 즉시 삭제(MVP).

import Combine
import Foundation

public protocol TimerUseCase {
    // 타이머 — 생성은 프리셋 원탭뿐 (키워드 직접 입력 생성 없음)
    func start(preset: TimerPresetModel)
    func pause(id: UUID)
    func resume(id: UUID)
    /// ±시간 — endAt 이동 (C1 카드 +1분)
    func extend(id: UUID, by seconds: Int)
    /// RINGING 확인 [+5분] — endAt = 지금 + 5분, RUNNING 복귀
    func snooze(id: UUID)
    /// [완료] 또는 정지(취소) — 즉시 삭제
    func remove(id: UUID)
    func updateMemo(id: UUID, memo: String?)
    /// RUNNING & endAt 도달 → RINGING 전이 (틱마다 호출)
    func refresh()
    /// 외부 프로세스(App Intent 등)가 App Group 저장소를 직접 바꾼 뒤 재동기화
    func reload()

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
    private var cancellables = Set<AnyCancellable>()

    public let timers = CurrentValueSubject<[TreatmentTimerModel], Never>([])
    public let presets = CurrentValueSubject<[TimerPresetModel], Never>([])
    public let alarmPermission = PassthroughSubject<TimerAlarmAuthorizationStatus, Never>()

    public init(repository: TimerRepositoryProtocol, alarmScheduler: TimerAlarmScheduling) {
        self.repository = repository
        self.alarmScheduler = alarmScheduler
        timers.send(repository.loadTimers())
        presets.send(repository.loadPresets())
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
                break // 울림 중 조정은 [+5분](snooze)로만
            }
        }
        if let scheduled {
            alarmScheduler.scheduleAlarm(id: id, label: scheduled.label, categoryName: scheduled.categoryName, body: scheduled.body, fireDate: scheduled.endAt)
        }
    }

    public func snooze(id: UUID) {
        var scheduled: (label: String, categoryName: String, body: String, endAt: Date)?
        mutate { list in
            guard let i = list.firstIndex(where: { $0.id == id }), list[i].state == .ringing else { return }
            let endAt = Date().addingTimeInterval(5 * 60)
            list[i].endAt = endAt
            list[i].state = .running
            scheduled = (list[i].label, list[i].category.displayName, alarmBody(duration: list[i].duration), endAt)
        }
        if let scheduled {
            alarmScheduler.scheduleAlarm(id: id, label: scheduled.label, categoryName: scheduled.categoryName, body: scheduled.body, fireDate: scheduled.endAt)
        }
    }

    public func remove(id: UUID) {
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
            .sink { [weak self] status in self?.alarmPermission.send(status) }
            .store(in: &cancellables)
    }

    public func fetchAlarmPermission() {
        alarmScheduler.authorizationStatus()
            .sink { [weak self] status in self?.alarmPermission.send(status) }
            .store(in: &cancellables)
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
