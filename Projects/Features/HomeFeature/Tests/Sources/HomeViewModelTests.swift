import XCTest
import Combine
import Domain
@testable import HomeFeature

final class HomeViewModelTests: XCTestCase {
    var sut: HomeViewModel!
    var mockUseCase: MockHomeUseCase!
    var cancelBag = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        mockUseCase = MockHomeUseCase()
        sut = HomeViewModel(useCase: mockUseCase)
    }

    func test_viewDidLoad_fetchesItems() {
        let stub = [HomeEntity(id: 1, title: "Test", description: "Desc", imageURL: nil)]
        mockUseCase.fetchItemsResult = .success(stub)

        let input = HomeViewModel.Input(
            viewDidLoad: Just(()).eraseToAnyPublisher(),
            itemSelected: Empty().eraseToAnyPublisher()
        )
        let output = sut.transform(input: input)

        let expectation = expectation(description: "items received")
        output.items
            .sink { items in
                XCTAssertEqual(items.count, 1)
                XCTAssertEqual(items.first?.title, "Test")
                expectation.fulfill()
            }
            .store(in: &cancelBag)

        waitForExpectations(timeout: 1)
    }
}

// MARK: - Mock
final class MockHomeUseCase: HomeUseCaseProtocol {
    var fetchItemsResult: Result<[HomeEntity], Error> = .success([])

    func fetchItems() -> AnyPublisher<[HomeEntity], Error> {
        fetchItemsResult.publisher.eraseToAnyPublisher()
    }

    func fetchItem(id: Int) -> AnyPublisher<HomeEntity, Error> {
        Empty().eraseToAnyPublisher()
    }
}
