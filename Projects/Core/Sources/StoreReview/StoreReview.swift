import Foundation
import StoreKit
import UIKit

/// 평가 창을 요청하는 순간 (spec: feature/pill-recognition/README.md §스토어 리뷰 요청 NM-618).
public enum StoreReviewMoment: Equatable {
    /// 식별 기록 저장 성공 → 들어온 화면으로 돌아온 직후.
    /// `allUnedited` = 이번에 확정한 알약을 모두 사용자 수정 없이 골랐다(수동 추가는 수정으로 본다).
    case identificationSaved(allUnedited: Bool)
    /// 앱 안에서 타이머를 끝낸 직후, 또는 앱 밖에서 끝낸 뒤 다음에 앱을 열 때.
    case timerCompleted
}

/// 요청 판단에 쓰는 기록 — 기기에만 둔다. 재설치하면 처음부터 센다.
public struct StoreReviewRecord: Codable, Equatable {
    public var firstLaunchAt: Date?
    /// 앱을 연 날(그날 0시). 최근 7일 판단에만 쓰므로 그보다 오래된 날은 버린다.
    public var activeDays: [Date] = []
    /// 기록 저장에 성공한 식별 수.
    public var identificationCount = 0
    /// 시작한 타이머 수 — 앱 · 워치 · 위젯 어디서 시작했든 센다.
    public var timerStartCount = 0
    public var lastRequestedAt: Date?
    /// 한도 안내 팝업을 마지막으로 본 날(그날 0시).
    public var limitAlertDay: Date?
    /// 앱 밖(시스템 알람 · 워치)에서 타이머를 끝냈다 — 다음에 앱을 열 때 판단한다.
    public var hasPendingTimerMoment = false

    public init() {}
}

/// 요청 조건. 아래 묶음 중 하나를 모두 만족하면 요청한다.
public enum StoreReviewPolicy {
    static let requestInterval = 30
    static let recentWindowDays = 7

    public static func shouldRequest(
        _ record: StoreReviewRecord,
        moment: StoreReviewMoment,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let today = calendar.startOfDay(for: now)
        func days(since date: Date?) -> Int? {
            guard let date else { return nil }
            return calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: today).day
        }

        // 공통 — 마지막 요청 후 30일 이상.
        if let elapsed = days(since: record.lastRequestedAt), elapsed < requestInterval { return false }
        let launchedDaysAgo = days(since: record.firstLaunchAt) ?? 0

        // 묶음 1 — 식별 누적 3회 · 첫 실행 후 3일 · 수정 없이 고름 · 오늘 한도 안내를 보지 않음.
        if case .identificationSaved(let allUnedited) = moment,
           record.identificationCount >= 3,
           launchedDaysAgo >= 3,
           allUnedited,
           record.limitAlertDay.map({ !calendar.isDate($0, inSameDayAs: today) }) ?? true {
            return true
        }

        // 묶음 2 — 최근 7일 중 3일 이상 접속 · 식별 · 타이머 사용 합쳐 3회 이상.
        let recentDays = Set(record.activeDays.compactMap { day -> Date? in
            guard let ago = days(since: day), ago < recentWindowDays else { return nil }
            return calendar.startOfDay(for: day)
        })
        if recentDays.count >= 3, record.identificationCount + record.timerStartCount >= 3 {
            return true
        }

        // 묶음 3 — 첫 실행 후 3일 · 타이머 누적 5회.
        return launchedDaysAgo >= 3 && record.timerStartCount >= 5
    }
}

/// 스토어 리뷰 요청 기록 · 판단 · 요청. 창을 띄울지는 OS가 정한다 — 요청해도 뜨지 않을 수 있다.
/// 화면 흐름(코디네이터 · 씬 · 워치 명령)에서 부르므로 메인 스레드에서만 쓴다.
public final class StoreReview {
    public static let shared = StoreReview()

    private static let recordKey = "storeReview.record"

    private let defaults: UserDefaults
    private let now: () -> Date
    private let calendar: Calendar
    private let present: @MainActor (UIWindowScene) -> Void

    public init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current,
        present: @escaping @MainActor (UIWindowScene) -> Void = { AppStore.requestReview(in: $0) }
    ) {
        self.defaults = defaults
        self.now = now
        self.calendar = calendar
        self.present = present
    }

    public private(set) var record: StoreReviewRecord {
        get {
            defaults.data(forKey: Self.recordKey)
                .flatMap { try? JSONDecoder().decode(StoreReviewRecord.self, from: $0) } ?? StoreReviewRecord()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: Self.recordKey) }
        }
    }

    // MARK: - 기록

    /// 앱이 활성화될 때마다 — 첫 실행 시각과 앱을 연 날을 남긴다.
    public func recordAppActive() {
        let today = calendar.startOfDay(for: now())
        var record = record
        if record.firstLaunchAt == nil { record.firstLaunchAt = now() }
        if !record.activeDays.contains(today) { record.activeDays.append(today) }
        let oldest = calendar.date(byAdding: .day, value: -(StoreReviewPolicy.recentWindowDays - 1), to: today) ?? today
        record.activeDays.removeAll { $0 < oldest }
        self.record = record
    }

    public func recordIdentificationSaved() {
        record.identificationCount += 1
    }

    public func recordTimerStarted(count: Int = 1) {
        guard count > 0 else { return }
        record.timerStartCount += count
    }

    public func recordLimitAlertShown() {
        record.limitAlertDay = calendar.startOfDay(for: now())
    }

    /// 앱 밖(시스템 알람 · 워치)에서 타이머를 끝냈다 — 앱이 앞에 없어 바로 요청할 수 없다.
    public func recordTimerCompletedOutsideApp() {
        record.hasPendingTimerMoment = true
    }

    // MARK: - 요청

    /// 조건을 보고 요청한다. 화면 전환이 끝난 뒤에 띄우도록 다음 런루프로 미룬다.
    public func requestIfEligible(_ moment: StoreReviewMoment) {
        guard StoreReviewPolicy.shouldRequest(record, moment: moment, now: now(), calendar: calendar) else { return }
        let scene = MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        }
        guard let scene else { return }
        record.lastRequestedAt = now()
        DispatchQueue.main.async { [present] in present(scene) }
    }

    /// 다음에 앱을 열 때 — 앱 밖에서 끝낸 타이머가 있으면 그 순간으로 판단한다.
    public func requestPendingTimerMomentIfNeeded() {
        guard record.hasPendingTimerMoment else { return }
        record.hasPendingTimerMoment = false
        requestIfEligible(.timerCompleted)
    }
}
