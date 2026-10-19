import Combine
import Foundation

import Core
import Domain

/*
 HomeViewModel 은 @Injected 로 PillUseCase·TimerUseCase 를 꺼내므로, 등록이 없으면
 DIContainer 가 fatalError 로 죽는다(조립 누락을 개발 중 드러내려는 의도된 동작).
 테스트 프로세스에는 앱의 조립 지점(RegisterDependencies)이 없으니 여기서 no-op 스텁을 넣는다.

 홈 화면 테스트가 검증하는 건 탭 → 콜백 전달이라, 스텁은 "아무것도 하지 않고 아무것도 방출하지 않는다".
 */
enum HomeTestDependencies {
    static func register() {
        let container = DIContainer.shared
        container.register(PillUseCase.self) { StubPillUseCase() }
        container.register(TimerUseCase.self) { StubTimerUseCase() }
        container.register(PillHistoryUseCase.self) { EmptyPillHistoryUseCase() }
    }
}

final class StubPillUseCase: PillUseCase {
    let pillAttributes = PassthroughSubject<[PillAttributeModel], Never>()
    let pillDetail = PassthroughSubject<PillDetailModel, Never>()
    let errorMessage = PassthroughSubject<String, Never>()
    let pillUsage = CurrentValueSubject<PillUsageModel?, Never>(nil)
    let limitExceeded = PassthroughSubject<PillUsageModel?, Never>()
    let pillDetailNotFound = PassthroughSubject<Void, Never>()
    let pillDetailFailure = PassthroughSubject<String, Never>()

    func fetchPillAttributes(items: [(pillId: String, croppedImage: String)]) {}
    func uploadOriginalImage(_ jpegData: Data) {}
    func fetchPillCandidates(query: PillCandidateQuery) -> AnyPublisher<PillCandidateResultModel, Error> {
        Empty().eraseToAnyPublisher()
    }
    func fetchPillCandidateItems(pillCodes: [String]) -> AnyPublisher<PillCandidateItemsModel, Error> {
        Empty().eraseToAnyPublisher()
    }
    func fetchPillDetail(pillCode: String) {}
    func fetchPillUsage() {}
    func resetAccountScopedState() {}
}

final class StubTimerUseCase: TimerUseCase {
    let timers = CurrentValueSubject<[TreatmentTimerModel], Never>([])
    let presets = CurrentValueSubject<[TimerPresetModel], Never>([])
    let alarmPermission = PassthroughSubject<TimerAlarmAuthorizationStatus, Never>()

    func start(preset: TimerPresetModel) {}
    func pause(id: UUID) {}
    func resume(id: UUID) {}
    func extend(id: UUID, by seconds: Int) {}
    func remove(id: UUID) {}
    func updateMemo(id: UUID, memo: String?) {}
    func refresh() {}
    func reload() {}
    func handleWatchCommand(_ command: TimerWatchCommand) {}
    func addPreset(label: String, category: TimerCategory, duration: Int) {}
    func updatePreset(_ preset: TimerPresetModel) {}
    func deletePreset(id: UUID) {}
    func movePreset(id: UUID, to index: Int) {}
    func requestAlarmPermission() {}
    func fetchAlarmPermission() {}
}

/// 식별 기록 스텁 — 기록이 하나도 없는 계정처럼 동작한다.
final class EmptyPillHistoryUseCase: PillHistoryUseCase {
    func fetchHistories(limit: Int, cursor: String?) -> AnyPublisher<PillHistoryPageModel, Error> {
        Just(PillHistoryPageModel(items: [], nextCursor: nil)).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    func fetchLatestHistory() -> AnyPublisher<PillHistorySummaryModel?, Error> {
        Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    func fetchHistory(historyId: String) -> AnyPublisher<PillHistoryModel, Error> {
        Fail(error: PillHistoryNotFoundError()).eraseToAnyPublisher()
    }
    func saveHistory(historyId: String, pillCodes: [String]) -> AnyPublisher<Void, Error> {
        Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    func deleteHistory(historyId: String) -> AnyPublisher<Void, Error> {
        Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
}
