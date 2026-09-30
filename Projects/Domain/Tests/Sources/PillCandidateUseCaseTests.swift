import Combine
import XCTest

@testable import Domain

/// 후보 조회 — 속성 토큰을 서버가 못 읽으면 토큰 없이 한 번 더 (NM-514).
final class PillCandidateUseCaseTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    func test_토큰_오류면_토큰_없이_다시_조회한다() throws {
        let repository = CandidateRepositorySpy()
        repository.responses = [.failure(PillInvalidAttributeTokenError()), .success(result)]

        let value = try firstValue(DefaultPillUseCase(repository: repository).fetchPillCandidates(query: query(token: "tok")))

        XCTAssertEqual(value, result)
        XCTAssertEqual(repository.queries.map(\.attributeToken), ["tok", nil])
    }

    func test_다른_오류는_다시_조회하지_않는다() {
        let repository = CandidateRepositorySpy()
        repository.responses = [.failure(URLError(.notConnectedToInternet))]

        XCTAssertThrowsError(try firstValue(DefaultPillUseCase(repository: repository).fetchPillCandidates(query: query(token: "tok"))))
        XCTAssertEqual(repository.queries.count, 1)
    }

    /// 토큰이 원래 없었는데 토큰 오류가 오면 되풀이할 것이 없다.
    func test_토큰이_없던_요청은_다시_조회하지_않는다() {
        let repository = CandidateRepositorySpy()
        repository.responses = [.failure(PillInvalidAttributeTokenError())]

        XCTAssertThrowsError(try firstValue(DefaultPillUseCase(repository: repository).fetchPillCandidates(query: query(token: nil))))
        XCTAssertEqual(repository.queries.count, 1)
    }

    // MARK: - Helpers

    private let result = PillCandidateResultModel(ids: ["A"], candidates: [], truncated: false)

    private func query(token: String?) -> PillCandidateQuery {
        PillCandidateQuery(attributeToken: token, colors: [], shape: nil, formulation: nil, front: nil, back: nil)
    }

    private func firstValue<T>(_ publisher: AnyPublisher<T, Error>) throws -> T {
        var output: Result<T, Error>?
        publisher.sink { completion in
            if case .failure(let error) = completion { output = .failure(error) }
        } receiveValue: { output = .success($0) }
        .store(in: &cancellables)
        return try XCTUnwrap(output).get()
    }
}

private final class CandidateRepositorySpy: PillRepositoryProtocol {
    var responses: [Result<PillCandidateResultModel, Error>] = []
    private(set) var queries: [PillCandidateQuery] = []

    func fetchPillCandidates(query: PillCandidateQuery) -> AnyPublisher<PillCandidateResultModel, Error> {
        queries.append(query)
        return responses.removeFirst().publisher.eraseToAnyPublisher()
    }

    func fetchPillCandidateItems(pillCodes: [String]) -> AnyPublisher<PillCandidateItemsModel, Error> { Empty().eraseToAnyPublisher() }
    func fetchPillAttributes(items: [(pillId: String, croppedImage: String)]) -> AnyPublisher<PillAttributeResultModel, Error> { Empty().eraseToAnyPublisher() }
    func uploadOriginalImage(_ jpegData: Data) -> AnyPublisher<Void, Error> { Empty().eraseToAnyPublisher() }
    func fetchPillDetail(pillCode: String) -> AnyPublisher<PillDetailModel, Error> { Empty().eraseToAnyPublisher() }
    func fetchPillUsage() -> AnyPublisher<PillUsageModel, Error> { Empty().eraseToAnyPublisher() }
}
