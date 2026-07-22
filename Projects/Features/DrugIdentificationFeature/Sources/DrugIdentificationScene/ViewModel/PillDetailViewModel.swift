import Combine
import Foundation
import Core
import Domain

// ⑩ 세부정보 화면 ViewModel — pillCode로 세부정보 조회. 로딩/로드/없음(404)/오류 상태.
public final class PillDetailViewModel {

    // MARK: - State

    enum State {
        case loading
        case loaded(PillDetailModel)
        case notFound              // 404 — '세부정보 없음' (NM-309). 재시도 무의미.
        case failure(message: String)
    }

    // MARK: - Input / Output

    struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
        let retry: AnyPublisher<Void, Never>
    }

    struct Output {
        let state: AnyPublisher<State, Never>
    }

    // MARK: - Dependencies

    @Injected private var pillUseCase: PillUseCase

    private let pillCode: String
    private var cancelBag = Set<AnyCancellable>()
    private let stateSubject = CurrentValueSubject<State, Never>(.loading)

    // MARK: - Init

    init(pillCode: String) {
        self.pillCode = pillCode
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        bindUseCase()

        Publishers.Merge(input.viewDidLoad, input.retry)
            .sink { [weak self] in self?.load() }
            .store(in: &cancelBag)

        return Output(state: stateSubject.eraseToAnyPublisher())
    }

    // MARK: - Pipeline

    private func load() {
        stateSubject.send(.loading)
        pillUseCase.fetchPillDetail(pillCode: pillCode)
    }

    private func bindUseCase() {
        pillUseCase.pillDetail
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detail in
                self?.stateSubject.send(.loaded(detail))
            }
            .store(in: &cancelBag)

        // 세부정보 전용 채널만 구독한다 — 공유 errorMessage를 쓰면 다른 화면 오류까지 섞인다.
        pillUseCase.pillDetailNotFound
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.stateSubject.send(.notFound) }
            .store(in: &cancelBag)

        pillUseCase.pillDetailFailure
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in self?.stateSubject.send(.failure(message: message)) }
            .store(in: &cancelBag)
    }
}
