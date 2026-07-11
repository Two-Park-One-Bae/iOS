import XCTest
import Combine
@testable import HomeFeature

final class HomeViewModelTests: XCTestCase {
    var sut: HomeViewModel!
    var cancelBag = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
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
            drugIdentifyTapped: Empty().eraseToAnyPublisher(),
            treatmentTimerTapped: tap.eraseToAnyPublisher()
        ))
        tap.send(())

        waitForExpectations(timeout: 1)
    }
}
