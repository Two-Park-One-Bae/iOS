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
        case revoked               // 허가 종료(REVOKED) — 조회 없이 안내 (NM-336/NM-342).
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
    private let licenseStatus: LicenseStatus
    private var cancelBag = Set<AnyCancellable>()
    private let stateSubject = CurrentValueSubject<State, Never>(.loading)

    // MARK: - Init

    init(pillCode: String, licenseStatus: LicenseStatus = .normal) {
        self.pillCode = pillCode
        self.licenseStatus = licenseStatus
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        // 허가 종료(REVOKED)는 허가정보가 없는 품목 — 조회 없이 안내만 표시한다(NM-336).
        // '데이터 없음'·'오류'와 구분되는 별도 상태다.
        guard licenseStatus != .revoked else {
            stateSubject.send(.revoked)
            return Output(state: stateSubject.eraseToAnyPublisher())
        }

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
