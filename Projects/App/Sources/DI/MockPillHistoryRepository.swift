#if DEBUG
import Combine
import Foundation

import Domain

/*
 식별 기록 API 목 (디버그 빌드 전용) — 서버 없이 빈 상태 · 실패 화면을 확인하는 데 쓴다.

 환경 변수 `MOCK_PILL_HISTORY` 에 아래 값을 쉼표로 이어 준다. 없으면 실제 API 를 그대로 쓴다.

   sample         목록 · 상세를 샘플 기록으로 (서버에 기록이 없어도 화면 확인)
   empty          목록이 빔 → 알약 탭 `아직 식별 기록이 없어요`, 홈 칩 숨김
   list_fail      목록 조회 실패 → 알약 탭 `기록을 불러오지 못했어요`, 홈 칩 숨김
   more_fail      두 번째 묶음부터 실패 → 목록 끝 `불러오지 못했어요 · 다시 시도` (sample 과 함께)
   detail_fail    한 건 조회 실패 → 기록 상세 `기록을 불러오지 못했어요`
   not_found      한 건 조회 404 → 들어온 화면으로 돌아가 `기록을 찾을 수 없어요`
   save_fail      저장 통신 실패 → `나가기` / `다시 시도`
   save_rejected  저장 400 → `나가기`만
   delete_fail    삭제 실패 → `기록을 삭제하지 못했어요`

 예) Xcode › Edit Scheme › Run › Environment Variables 에 MOCK_PILL_HISTORY = sample,save_fail
     시뮬레이터: SIMCTL_CHILD_MOCK_PILL_HISTORY=list_fail xcrun simctl launch booted app.nursemate.app
 */
final class MockPillHistoryRepository: PillHistoryRepositoryProtocol {

    /// 환경 변수가 있으면 목을, 없으면 nil — 조립 지점이 실제 저장소를 쓴다.
    static func fromEnvironment(fallback: PillHistoryRepositoryProtocol) -> PillHistoryRepositoryProtocol? {
        guard let raw = ProcessInfo.processInfo.environment["MOCK_PILL_HISTORY"], !raw.isEmpty else { return nil }
        let modes = Set(raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        return MockPillHistoryRepository(modes: modes, fallback: fallback)
    }

    private let modes: Set<String>
    private let fallback: PillHistoryRepositoryProtocol
    /// 응답이 바로 오면 조회 중 · 저장 중 화면이 안 보여 조금 늦춘다.
    private let delay: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(800)

    private init(modes: Set<String>, fallback: PillHistoryRepositoryProtocol) {
        self.modes = modes
        self.fallback = fallback
    }

    // MARK: - PillHistoryRepositoryProtocol

    func fetchHistories(limit: Int, cursor: String?) -> AnyPublisher<PillHistoryPageModel, Error> {
        if modes.contains("list_fail") { return fail(Self.networkError) }
        if modes.contains("more_fail"), cursor != nil { return fail(Self.networkError) }
        if modes.contains("empty") { return just(PillHistoryPageModel(items: [], nextCursor: nil)) }
        guard modes.contains("sample") else { return fallback.fetchHistories(limit: limit, cursor: cursor) }

        // 샘플 25건 — 20건씩 받으면 두 번째 묶음이 생겨 이어 받기 · more_fail 을 볼 수 있다.
        let offset = Int(cursor ?? "0") ?? 0
        let all = Self.sampleSummaries
        let page = Array(all.dropFirst(offset).prefix(limit))
        let next = offset + page.count < all.count ? String(offset + page.count) : nil
        return just(PillHistoryPageModel(items: page, nextCursor: next))
    }

    func fetchHistory(historyId: String) -> AnyPublisher<PillHistoryModel, Error> {
        if modes.contains("not_found") { return fail(PillHistoryNotFoundError()) }
        if modes.contains("detail_fail") { return fail(Self.networkError) }
        guard modes.contains("sample") else { return fallback.fetchHistory(historyId: historyId) }

        let summary = Self.sampleSummaries.first { $0.historyId == historyId }
        let pills = Array(Self.samplePills.prefix(summary?.pillCount ?? 3))
        return just(PillHistoryModel(historyId: historyId, identifiedAt: summary?.identifiedAt ?? Date(), pills: pills))
    }

    func saveHistory(historyId: String, pillCodes: [String]) -> AnyPublisher<Void, Error> {
        if modes.contains("save_rejected") { return fail(PillHistoryRejectedError()) }
        if modes.contains("save_fail") { return fail(Self.networkError) }
        guard modes.contains("sample") else { return fallback.saveHistory(historyId: historyId, pillCodes: pillCodes) }
        return just(())
    }

    func deleteHistory(historyId: String) -> AnyPublisher<Void, Error> {
        if modes.contains("delete_fail") { return fail(Self.networkError) }
        guard modes.contains("sample") else { return fallback.deleteHistory(historyId: historyId) }
        return just(())
    }

    // MARK: - Helpers

    private static let networkError = URLError(.notConnectedToInternet)

    private func just<T>(_ value: T) -> AnyPublisher<T, Error> {
        Just(value)
            .setFailureType(to: Error.self)
            .delay(for: delay, scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    private func fail<T>(_ error: Error) -> AnyPublisher<T, Error> {
        Fail(error: error)
            .delay(for: delay, scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: - Sample

    private static let samplePills: [PillHistoryPillModel] = [
        .init(pillCode: "200808876", pillName: "타이레놀정500밀리그람", companyName: "한국존슨앤드존슨판매", licenseStatus: .normal, pillThumbnailUrl: nil),
        .init(pillCode: "199303108", pillName: "세파클러캡슐250밀리그램", companyName: "종근당", licenseStatus: .normal, pillThumbnailUrl: nil),
        .init(pillCode: "197900307", pillName: "게보린정", companyName: "삼진제약", licenseStatus: .normal, pillThumbnailUrl: nil),
        .init(pillCode: "198600153", pillName: "펜잘큐정", companyName: "종근당", licenseStatus: .revoked, pillThumbnailUrl: nil),
        .init(pillCode: "201100345", pillName: "마이티셋정", companyName: "제이알피", licenseStatus: .normal, pillThumbnailUrl: nil),
    ]

    /// 오늘 3건 · 어제 2건 · 그 전 날짜들 — 날짜 묶음과 긴 품목명 말줄임을 함께 본다.
    private static let sampleSummaries: [PillHistorySummaryModel] = {
        let names = [
            "타이레놀정500밀리그람", "세파클러캡슐250밀리그램", "게보린정", "마이티셋정", "아세트정",
            "타이레놀8시간이알서방정650밀리그람(아세트아미노펜)", "펜잘큐정", "알마겔정", "베아제정", "훼스탈플러스정",
        ]
        let now = Date()
        let hour: TimeInterval = 3600
        let offsets: [TimeInterval] = [1, 3, 5, 26, 30] + (0..<20).map { TimeInterval(50 + $0 * 20) }
        return offsets.enumerated().map { index, hoursAgo in
            PillHistorySummaryModel(
                historyId: String(format: "00000000-0000-4000-8000-%012d", index),
                identifiedAt: now.addingTimeInterval(-hoursAgo * hour),
                firstPillName: names[index % names.count],
                pillCount: index % 5 + 1
            )
        }
    }()
}
#endif
