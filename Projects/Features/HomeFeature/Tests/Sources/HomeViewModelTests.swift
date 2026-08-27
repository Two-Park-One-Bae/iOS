import XCTest
import Combine
@testable import HomeFeature

final class HomeViewModelTests: XCTestCase {
    var sut: HomeViewModel!
    var cancelBag = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        // HomeViewModel 이 init 시점에 @Injected 로 UseCase 를 꺼내므로 생성 전에 등록해야 한다.
        HomeTestDependencies.register()
        sut = HomeViewModel()
    }

    override func tearDown() {
        sut = nil
        cancelBag.removeAll()
        super.tearDown()
    }

    func test_drugIdentifyTapped_triggersNavigationCallback() {
        let expectation = expectation(description: "drug identify callback fired")
        sut.onDrugIdentifyTapped = { expectation.fulfill() }

        let tap = PassthroughSubject<Void, Never>()
        _ = sut.transform(input: HomeViewModel.Input(
            viewDidLoad: Empty().eraseToAnyPublisher(),
            viewWillAppear: Empty().eraseToAnyPublisher(),
            drugIdentifyTapped: tap.eraseToAnyPublisher(),
            treatmentTimerTapped: Empty().eraseToAnyPublisher()
        ))
        tap.send(())

        waitForExpectations(timeout: 1)
    }

    func test_treatmentTimerTapped_triggersNavigationCallback() {
        let expectation = expectation(description: "treatment timer callback fired")
        sut.onTreatmentTimerTapped = { expectation.fulfill() }

        let tap = PassthroughSubject<Void, Never>()
        _ = sut.transform(input: HomeViewModel.Input(
            viewDidLoad: Empty().eraseToAnyPublisher(),
            viewWillAppear: Empty().eraseToAnyPublisher(),
            drugIdentifyTapped: Empty().eraseToAnyPublisher(),
            treatmentTimerTapped: tap.eraseToAnyPublisher()
        ))
        tap.send(())

        waitForExpectations(timeout: 1)
    }
}
