import XCTest
@testable import Core

/// 스토어 리뷰 요청 조건 (spec: feature/pill-recognition/README.md §스토어 리뷰 요청 NM-618).
final class StoreReviewPolicyTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()
    private lazy var now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 14))!

    private func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: now)!
    }

    private func shouldRequest(_ record: StoreReviewRecord, _ moment: StoreReviewMoment) -> Bool {
        StoreReviewPolicy.shouldRequest(record, moment: moment, now: now, calendar: calendar)
    }

    /// 묶음 1 을 모두 채운 기록.
    private var identificationRecord: StoreReviewRecord {
        var record = StoreReviewRecord()
        record.firstLaunchAt = daysAgo(3)
        record.identificationCount = 3
        return record
    }

    // MARK: - 묶음 1

    func test_묶음1_모두_만족하면_요청() {
        XCTAssertTrue(shouldRequest(identificationRecord, .identificationSaved(allUnedited: true)))
    }

    func test_묶음1_수정했으면_요청하지_않음() {
        XCTAssertFalse(shouldRequest(identificationRecord, .identificationSaved(allUnedited: false)))
    }

    func test_묶음1_식별_2회면_요청하지_않음() {
        var record = identificationRecord
        record.identificationCount = 2
        XCTAssertFalse(shouldRequest(record, .identificationSaved(allUnedited: true)))
    }

    func test_묶음1_첫_실행_2일째면_요청하지_않음() {
        var record = identificationRecord
        record.firstLaunchAt = daysAgo(2)
        XCTAssertFalse(shouldRequest(record, .identificationSaved(allUnedited: true)))
    }

    func test_묶음1_오늘_한도_안내를_봤으면_요청하지_않고_어제면_요청() {
        var record = identificationRecord
        record.limitAlertDay = calendar.startOfDay(for: now)
        XCTAssertFalse(shouldRequest(record, .identificationSaved(allUnedited: true)))
        record.limitAlertDay = calendar.startOfDay(for: daysAgo(1))
        XCTAssertTrue(shouldRequest(record, .identificationSaved(allUnedited: true)))
    }

    func test_묶음1은_타이머_시점에_쓰지_않음() {
        XCTAssertFalse(shouldRequest(identificationRecord, .timerCompleted))
    }

    // MARK: - 묶음 2

    func test_묶음2_최근_7일_중_3일_접속과_사용_3회면_요청() {
        var record = StoreReviewRecord()
        record.firstLaunchAt = now
        record.activeDays = [0, 3, 6].map { calendar.startOfDay(for: daysAgo($0)) }
        record.identificationCount = 1
        record.timerStartCount = 2
        XCTAssertTrue(shouldRequest(record, .timerCompleted))
        XCTAssertTrue(shouldRequest(record, .identificationSaved(allUnedited: false)))
    }

    func test_묶음2_7일보다_오래된_접속은_세지_않음() {
        var record = StoreReviewRecord()
        record.activeDays = [0, 3, 7].map { calendar.startOfDay(for: daysAgo($0)) }
        record.timerStartCount = 3
        XCTAssertFalse(shouldRequest(record, .timerCompleted))
    }

    // MARK: - 묶음 3

    func test_묶음3_첫_실행_3일과_타이머_5회면_요청() {
        var record = StoreReviewRecord()
        record.firstLaunchAt = daysAgo(3)
        record.timerStartCount = 5
        XCTAssertTrue(shouldRequest(record, .timerCompleted))
        record.timerStartCount = 4
        XCTAssertFalse(shouldRequest(record, .timerCompleted))
    }

    func test_묶음3은_식별_시점에_쓰지_않음() {
        var record = StoreReviewRecord()
        record.firstLaunchAt = daysAgo(3)
        record.timerStartCount = 5
        XCTAssertFalse(shouldRequest(record, .identificationSaved(allUnedited: true)))
    }

    // MARK: - 공통

    func test_마지막_요청_후_30일이_안_됐으면_어느_묶음도_요청하지_않음() {
        var record = identificationRecord
        record.timerStartCount = 5
        record.lastRequestedAt = daysAgo(29)
        XCTAssertFalse(shouldRequest(record, .identificationSaved(allUnedited: true)))
        XCTAssertFalse(shouldRequest(record, .timerCompleted))
        record.lastRequestedAt = daysAgo(30)
        XCTAssertTrue(shouldRequest(record, .timerCompleted))
    }

    // MARK: - 기록

    @MainActor
    func test_앱을_연_날은_하루에_한_번만_남고_7일이_지나면_버림() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        var clock = daysAgo(8)
        let review = StoreReview(defaults: defaults, now: { clock }, calendar: calendar, present: { _ in })

        review.recordAppActive()
        clock = now
        review.recordAppActive()
        review.recordAppActive()

        XCTAssertEqual(review.record.firstLaunchAt, daysAgo(8))
        XCTAssertEqual(review.record.activeDays, [calendar.startOfDay(for: now)])
    }

    @MainActor
    func test_위젯만_3일_쓰고_4일째_앱을_열면_쓴_날이_4일이다() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let review = StoreReview(defaults: defaults, now: { self.now }, calendar: calendar, present: { _ in })

        review.recordAppActive()
        // 큐에 남은 위젯 시작 · 앱 밖 완료 — 1 · 2 · 3일 전, 그리고 7일보다 오래된 것 하나
        review.recordTimerStarted(at: [daysAgo(3), daysAgo(2), daysAgo(1), daysAgo(9)])
        review.recordTimerCompletedOutsideApp(at: [daysAgo(1)])

        XCTAssertEqual(review.record.activeDays, [3, 2, 1, 0].map { calendar.startOfDay(for: daysAgo($0)) })
        XCTAssertEqual(review.record.timerStartCount, 4)
        // 처음 쓴 시각도 위젯 사용(9일 전)으로 당겨진다.
        XCTAssertEqual(review.record.firstLaunchAt, daysAgo(9))
        XCTAssertTrue(StoreReviewPolicy.shouldRequest(review.record, moment: .timerCompleted, now: now, calendar: calendar))
    }

    @MainActor
    func test_앱_밖에서_끝낸_타이머는_띄울_씬이_없으면_다음_활성화까지_남긴다() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let review = StoreReview(defaults: defaults, now: { self.now }, calendar: calendar, present: { _ in })

        review.recordTimerCompletedOutsideApp()
        XCTAssertTrue(review.record.hasPendingTimerMoment)
        // 호스트 앱 없는 테스트라 앞에 떠 있는 씬이 없다.
        review.requestPendingTimerMomentIfNeeded(in: nil)
        XCTAssertTrue(review.record.hasPendingTimerMoment)
    }
}
