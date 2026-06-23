import XCTest
import Combine
@testable import Domain

final class HomeUseCaseTests: XCTestCase {
    var sut: DefaultHomeUseCase!
    var mockRepository: MockHomeRepository!
    var cancelBag = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        mockRepository = MockHomeRepository()
        sut = DefaultHomeUseCase(repository: mockRepository)
    }

    func test_fetchItems_success() {
        let stub = [HomeEntity(id: 1, title: "Test", description: "Desc", imageURL: nil)]
        mockRepository.fetchItemsResult = .success(stub)

        let expectation = expectation(description: "fetchItems")
        sut.fetchItems()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { items in
                    XCTAssertEqual(items.count, 1)
                    XCTAssertEqual(items.first?.title, "Test")
                    expectation.fulfill()
                }
            )
            .store(in: &cancelBag)

        waitForExpectations(timeout: 1)
    }
}

// MARK: - Mock
final class MockHomeRepository: HomeRepositoryProtocol {
    var fetchItemsResult: Result<[HomeEntity], Error> = .success([])

    func fetchItems() -> AnyPublisher<[HomeEntity], Error> {
        fetchItemsResult.publisher.eraseToAnyPublisher()
    }

    func fetchItem(id: Int) -> AnyPublisher<HomeEntity, Error> {
        Empty().eraseToAnyPublisher()
    }
}
