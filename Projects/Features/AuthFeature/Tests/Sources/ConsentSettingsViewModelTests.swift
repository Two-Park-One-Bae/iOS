import Combine
import XCTest

import Core
import Domain
@testable import AuthFeature

/// 약관 및 동의 화면 규칙 (NM-548).
///
/// spec(feature/auth/README.md §약관 및 동의 화면)이 못박은 것들을 고정한다 —
/// 필수는 고정, 선택은 현재 상태로 시작, 바뀐 것만 저장, 400 은 재조회, 그 밖의 실패는 되돌림.
final class ConsentSettingsViewModelTests: XCTestCase {

    private var useCase: StubAuthUseCase!
    private var sut: ConsentSettingsViewModel!
    private var cancelBag = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        let stub = StubAuthUseCase()
        useCase = stub
        DIContainer.shared.register(AuthUseCase.self) { stub }
        sut = ConsentSettingsViewModel()
    }

    override func tearDown() {
        cancelBag.removeAll()
        sut = nil
        useCase = nil
        super.tearDown()
    }

    // MARK: - 시작 상태

    func test_현재버전에_동의했으면_체크된_채_시작한다() {
        useCase.user.send(.stub(consents: [.init(type: .overseas, agreed: true, version: "1.0", satisfied: true)]))
        load()

        XCTAssertEqual(sut.checked.value, [.overseas])
        XCTAssertFalse(latestCanSave(), "바뀐 것이 없으면 저장할 수 없다")
    }

    func test_옛버전_동의는_체크되지_않은_채_시작한다() {
        useCase.user.send(.stub(consents: [.init(type: .overseas, agreed: true, version: "0.9", satisfied: false)]))
        load()

        XCTAssertTrue(sut.checked.value.isEmpty)
    }

    func test_서버에_선택항목이_없으면_필수만_보인다() {
        load([.stub(.terms), .stub(.privacy)])

        XCTAssertEqual(sut.definitions.value.map(\.type), [.terms, .privacy])
    }

    func test_필수항목은_바꿀_수_없다() {
        load()

        sut.toggle(.terms)

        XCTAssertFalse(sut.checked.value.contains(.terms))
        XCTAssertFalse(latestCanSave())
    }

    // MARK: - 저장

    func test_체크를_바꾸면_저장할_수_있고_되돌리면_다시_막힌다() {
        load()

        sut.toggle(.overseas)
        XCTAssertTrue(latestCanSave())

        sut.toggle(.overseas)
        XCTAssertFalse(latestCanSave())
    }

    func test_철회는_바뀐_항목만_agreed_false로_보낸다() {
        useCase.user.send(.stub(consents: [.init(type: .overseas, agreed: true, version: "1.0", satisfied: true)]))
        load()
        sut.toggle(.overseas)

        saveAndWait()

        XCTAssertEqual(useCase.updatedChanges, [ConsentAgreement(type: .overseas, version: "1.0", agreed: false)])
        XCTAssertFalse(latestCanSave(), "저장한 상태가 새 기준이 된다")
    }

    func test_저장에_실패하면_체크를_되돌린다() {
        load()
        sut.toggle(.overseas)
        useCase.updateResult = .failure(AuthError.serverError)

        saveAndWait()

        XCTAssertTrue(sut.checked.value.isEmpty)
    }

    func test_저장_400이면_정의를_재조회한다() {
        load()
        XCTAssertEqual(useCase.fetchCallCount, 1)
        sut.toggle(.overseas)
        useCase.updateResult = .failure(AuthError.consentVersionMismatch)

        let reloaded = expectation(description: "정의 재조회")
        sut.definitions.dropFirst().sink { _ in reloaded.fulfill() }.store(in: &cancelBag)
        sut.save()
        wait(for: [reloaded], timeout: 2)

        XCTAssertEqual(useCase.fetchCallCount, 2)
    }

    // MARK: - Helpers

    private func load(_ definitions: [ConsentDefinition] = [.stub(.terms), .stub(.privacy), .stub(.overseas)]) {
        useCase.definitions = definitions
        let loaded = expectation(description: "정의 로드")
        var bag = Set<AnyCancellable>()
        sut.definitions.dropFirst().sink { _ in loaded.fulfill() }.store(in: &bag)
        sut.load()
        wait(for: [loaded], timeout: 2)
        bag.removeAll()
    }

    private func saveAndWait() {
        let settled = expectation(description: "저장 완료")
        sut.isLoading.dropFirst(2).first().sink { _ in settled.fulfill() }.store(in: &cancelBag)
        sut.save()
        wait(for: [settled], timeout: 2)
    }

    private func latestCanSave() -> Bool {
        var value = false
        var bag = Set<AnyCancellable>()
        sut.canSave.sink { value = $0 }.store(in: &bag)
        return value
    }
}
