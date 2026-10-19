import XCTest
import Combine
import Domain
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

    func test_captureTapped_triggersNavigationCallback() {
        let expectation = expectation(description: "capture callback fired")
        sut.onCaptureTapped = { expectation.fulfill() }

        let tap = PassthroughSubject<Void, Never>()
        _ = sut.transform(input: HomeViewModel.Input(
            viewWillAppear: Empty().eraseToAnyPublisher(),
            captureTapped: tap.eraseToAnyPublisher()
        ))
        tap.send(())

        waitForExpectations(timeout: 1)
    }

    func test_timerCardTapped_triggersNavigationCallback() {
        let expectation = expectation(description: "timer tab callback fired")
        sut.onTimerTabTapped = { expectation.fulfill() }

        let tap = PassthroughSubject<Void, Never>()
        _ = sut.transform(input: HomeViewModel.Input(
            viewWillAppear: Empty().eraseToAnyPublisher(),
            timerCardTapped: tap.eraseToAnyPublisher()
        ))
        tap.send(())

        waitForExpectations(timeout: 1)
    }

    /// 순서: 만료 → 진행 중(남은 시간이 짧은 순) → 일시정지, 3줄까지 (spec: feature/home/README.md).
    func test_makeTimerList_ordersAndCapsAtThree() {
        let now = Date()
        func timer(_ label: String, _ state: TreatmentTimerState, remaining: Int) -> TreatmentTimerModel {
            TreatmentTimerModel(
                label: label, category: .treatment, duration: 3600,
                endAt: now.addingTimeInterval(TimeInterval(remaining)),
                remaining: state == .paused ? remaining : nil, state: state
            )
        }
        let list = HomeViewModel.makeTimerList([
            timer("일시정지", .paused, remaining: 10),
            timer("긴 진행", .running, remaining: 900),
            timer("짧은 진행", .running, remaining: 60),
            timer("만료", .ringing, remaining: 0),
        ], now: now)

        XCTAssertEqual(list.rows.map(\.label), ["만료", "짧은 진행", "긴 진행"])
        XCTAssertEqual(list.totalCount, 4)
        XCTAssertTrue(list.showsAll)
    }
}
