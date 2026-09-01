//
//  PillDwellTracker.swift
//  DrugIdentificationFeature
//

import UIKit

/// 알약 1개를 확정하기까지 **수정 화면이 실제로 화면에 떠 있던 시간**을 누적한다
/// (`pill_confirm.dwell_ms` / `dwell_bucket`).
///
/// ## 왜 벽시계를 안 쓰나
///
/// 예전엔 `viewDidLoad` 시각과 확정 시각의 차이를 그대로 보냈다. 그러면 두 방향으로 틀어진다.
///
///  - **과대** — 탭을 옮기거나 앱을 백그라운드로 내려도 시계가 계속 갔다. 실측에서 30초 백그라운드가
///    그대로 얹혀 72.8초짜리 작업이 102.8초로 기록됐고, 구간이 `01:00-01:30` 에서 `01:30-02:00` 로
///    한 칸 밀렸다. 분포를 보려는 지표에서 이건 치명적이다.
///  - **과소** — 화면을 나갔다 다시 들어오면 `PillEditVC` 가 새로 만들어져 시계가 0부터 다시 갔다.
///    같은 알약을 두 번에 걸쳐 고민하면 마지막 방문 시간만 남았다.
///
/// 그래서 **화면 노출 구간만 더하고, 그 합을 알약별로 세션 내내 들고 있는다.**
/// VC 가 다시 만들어져도 이 객체는 Coordinator 가 들고 있으므로 누적값이 이어진다.
///
/// ## 왜 훅이 두 쌍인가
///
/// iOS 는 **앱을 백그라운드로 내려도 `viewDidDisappear` 를 부르지 않는다.** 화면 전환만으로는
/// 백그라운드를 못 잡고, 앱 생명주기만으로는 탭 전환을 못 잡는다. 둘 다 필요하다.
///
///  - `viewDidAppear` / `viewDidDisappear` → 탭 전환, 다른 화면 push
///  - `didEnterBackground` / `willEnterForeground` → 앱 백그라운드
///
/// 백그라운드는 `activeIndex` 를 남긴 채 구간만 끊고(`suspend`), 복귀 시 그 알약으로 다시 잇는다.
/// 화면 전환은 `activeIndex` 까지 지운다(`pause`) — 복귀해도 자동으로 이어지면 안 되고,
/// 그 화면이 실제로 다시 뜰 때 `viewDidAppear` 가 이어 붙이는 게 맞다.
///
/// ## 포함하지 않는 것
///
/// 후보 세부정보·이미지 비교 뷰어를 보는 시간은 **빠진다** — 그 화면이 뜨는 동안 수정 화면은
/// 가려지기 때문이다. "그 알약을 판단하는 데 쓴 시간"으로 보면 포함이 맞다는 해석도 가능해서,
/// 지표를 그렇게 정의하기로 하면 push 구간만 예외로 이어 주면 된다.
final class PillDwellTracker {

    /// 알약 순번 → 지금까지 누적된 화면 노출 시간.
    private var accumulated: [Int: TimeInterval] = [:]
    /// 현재 화면에 떠 있는 알약. 화면이 가려지면 nil, 백그라운드에서는 유지된다.
    private var activeIndex: Int?
    /// 현재 구간의 시작 시각. 구간이 끊긴 상태면 nil.
    private var segmentStart: Date?

    private var observers: [NSObjectProtocol] = []

    init(notificationCenter: NotificationCenter = .default) {
        observers = [
            notificationCenter.addObserver(
                forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.suspend() },
            notificationCenter.addObserver(
                forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.resumeAfterForeground() }
        ]
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    // MARK: - 세션

    /// 새 인식 세션 시작 시 호출. Coordinator 는 탭당 하나라 앱 수명 내내 살아 있어서,
    /// 비우지 않으면 이전 사진의 알약 순번과 누적값이 섞인다.
    func reset() {
        accumulated.removeAll()
        activeIndex = nil
        segmentStart = nil
    }

    // MARK: - 화면 전환

    /// 수정 화면이 떴다 (`viewDidAppear`).
    func resume(pillIndex: Int) {
        activeIndex = pillIndex
        segmentStart = Date()
    }

    /// 수정 화면이 가려졌다 (`viewDidDisappear`).
    func pause() {
        flush()
        activeIndex = nil
    }

    // MARK: - 앱 생명주기

    /// 앱이 백그라운드로 갔다. `viewDidDisappear` 는 불리지 않으므로 여기서 구간을 끊는다.
    /// 어느 알약이었는지는 남겨 둬야 복귀 시 이어 붙일 수 있다.
    private func suspend() {
        flush()
    }

    /// 앱이 돌아왔다. 화면이 여전히 그 알약을 보고 있을 때만 구간을 다시 연다 —
    /// 다른 탭에 있다가 복귀한 경우엔 `activeIndex` 가 이미 nil 이라 아무 일도 하지 않는다.
    private func resumeAfterForeground() {
        guard activeIndex != nil, segmentStart == nil else { return }
        segmentStart = Date()
    }

    // MARK: - 조회

    /// 지금까지 누적된 화면 노출 시간(ms). 진행 중인 구간이 있으면 함께 더한다.
    func elapsedMs(pillIndex: Int) -> Int {
        var total = accumulated[pillIndex] ?? 0
        if activeIndex == pillIndex, let segmentStart {
            total += Date().timeIntervalSince(segmentStart)
        }
        return Int(total * 1000)
    }

    // MARK: - 내부

    /// 진행 중인 구간을 누적에 더하고 닫는다.
    private func flush() {
        guard let activeIndex, let segmentStart else { return }
        accumulated[activeIndex, default: 0] += Date().timeIntervalSince(segmentStart)
        self.segmentStart = nil
    }
}
