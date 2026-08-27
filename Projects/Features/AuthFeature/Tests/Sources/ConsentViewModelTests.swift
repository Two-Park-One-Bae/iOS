import Combine
import XCTest

import Core
import Domain
@testable import AuthFeature

/// 약관 동의 화면 규칙 (NM-409).
///
/// spec(feature/auth/README.md §동의 온보딩)이 못박은 것들을 고정한다 —
/// 필수 전체 동의 전에는 진행 불가, 재조회 시 체크 초기화, 400 은 오류가 아니라 재조회.
final class ConsentViewModelTests: XCTestCase {

    private var useCase: StubAuthUseCase!
    private var sut: ConsentViewModel!
    private var cancelBag = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        let stub = StubAuthUseCase()
        useCase = stub
        // ConsentViewModel 이 init 시점에 @Injected 로 꺼내므로 생성 전에 등록해야 한다.
        DIContainer.shared.register(AuthUseCase.self) { stub }
        sut = ConsentViewModel()
    }

    override func tearDown() {
        cancelBag.removeAll()
        sut = nil
        useCase = nil
        super.tearDown()
    }

    // MARK: - 진행 가능 조건

    func test_필수항목이_모두_체크돼야_진행할_수_있다() {
        loadDefinitions([.stub(.terms), .stub(.privacy)])

        XCTAssertFalse(latestCanProceed(), "아무것도 안 골랐으면 진행 불가")

        sut.toggle(.terms)
        XCTAssertFalse(latestCanProceed(), "하나만 골라도 진행 불가 — 필수 2종 전부여야 한다")

        sut.toggle(.privacy)
        XCTAssertTrue(latestCanProceed())
    }

    func test_필수를_다_골랐다가_하나_해제하면_다시_막힌다() {
        loadDefinitions([.stub(.terms), .stub(.privacy)])
        sut.toggle(.terms)
        sut.toggle(.privacy)
        XCTAssertTrue(latestCanProceed())

        sut.toggle(.terms)
        XCTAssertFalse(latestCanProceed())
    }

    // MARK: - 전체 동의

    func test_전체동의는_하나라도_빠져_있으면_모두_켠다() {
        loadDefinitions([.stub(.terms), .stub(.privacy)])
        sut.toggle(.terms)

        sut.toggleAll()

        XCTAssertEqual(sut.checked.value, [.terms, .privacy])
    }

    func test_전체동의는_모두_켜져_있으면_모두_끈다() {
        loadDefinitions([.stub(.terms), .stub(.privacy)])
        sut.toggleAll()
        XCTAssertEqual(sut.checked.value, [.terms, .privacy])

        sut.toggleAll()

        XCTAssertTrue(sut.checked.value.isEmpty)
    }

    // MARK: - 재조회

    /// 예전 체크가 남으면 사용자가 보지도 않은 새 버전에 동의한 것처럼 보인다.
    func test_정의를_다시_불러오면_체크가_초기화된다() {
        loadDefinitions([.stub(.terms), .stub(.privacy)])
        sut.toggleAll()
        XCTAssertFalse(sut.checked.value.isEmpty)

        loadDefinitions([.stub(.terms, version: "2.0"), .stub(.privacy, version: "2.0")])

        XCTAssertTrue(sut.checked.value.isEmpty)
        XCTAssertEqual(sut.definitions.value.first?.version, "2.0")
    }

    /// 저장 중 서버가 약관 버전을 올린 경우. 오류로 끝내지 않고 새 버전으로 화면을 다시 그린다.
    func test_동의저장_400이면_정의를_재조회한다() {
        loadDefinitions([.stub(.terms), .stub(.privacy)])
        XCTAssertEqual(useCase.fetchCallCount, 1)
        useCase.agreeResult = .failure(AuthError.consentVersionMismatch)

        let reloaded = expectation(description: "정의 재조회")
        sut.definitions.dropFirst().sink { _ in reloaded.fulfill() }.store(in: &cancelBag)
        sut.agree()
        wait(for: [reloaded], timeout: 2)

        XCTAssertEqual(useCase.fetchCallCount, 2, "400 은 오류로 끝내지 않고 다시 받아온다")
    }

    // MARK: - 저장 결과

    func test_동의저장_성공하면_완료콜백을_부른다() {
        loadDefinitions([.stub(.terms), .stub(.privacy)])
        useCase.agreeResult = .success(.home)

        let completed = expectation(description: "완료")
        sut.onCompleted = { completed.fulfill() }
        sut.agree()

        wait(for: [completed], timeout: 2)
    }

    /// 저장에 성공했어도 서버가 아직 미충족이라 하면 화면에 남아야 한다 —
    /// 앱이 스스로 충족됐다고 단정하지 않는다.
    func test_동의저장_응답이_미충족이면_완료콜백을_부르지_않는다() {
        loadDefinitions([.stub(.terms), .stub(.privacy)])
        useCase.agreeResult = .success(.consent)

        sut.onCompleted = { XCTFail("미충족인데 홈으로 넘어가면 안 된다") }
        let settled = expectation(description: "저장 완료")
        sut.isLoading.dropFirst(2).sink { _ in settled.fulfill() }.store(in: &cancelBag)
        sut.agree()

        wait(for: [settled], timeout: 2)
    }

    // MARK: - 취소

    /// 동의 없이 홈으로 가는 경로는 없다 — 취소의 결과는 로그아웃뿐이다.
    func test_취소하면_로그아웃한다() {
        let cancelled = expectation(description: "취소")
        sut.onCancelled = { cancelled.fulfill() }

        sut.cancelAndSignOut()

        wait(for: [cancelled], timeout: 1)
        XCTAssertEqual(useCase.signOutCallCount, 1)
    }

    // MARK: - Helpers

    private func loadDefinitions(_ definitions: [ConsentDefinition]) {
        useCase.definitions = definitions
        let loaded = expectation(description: "정의 로드")
        var bag = Set<AnyCancellable>()
        sut.definitions.dropFirst().sink { _ in loaded.fulfill() }.store(in: &bag)
        sut.load()
        wait(for: [loaded], timeout: 2)
        bag.removeAll()
    }

    private func latestCanProceed() -> Bool {
        var value = false
        var bag = Set<AnyCancellable>()
        sut.canProceed.sink { value = $0 }.store(in: &bag)
        return value
    }
}

// MARK: - Stub

private final class StubAuthUseCase: AuthUseCase {

    let user = CurrentValueSubject<AuthUser?, Never>(nil)

    var definitions: [ConsentDefinition] = []
    var agreeResult: Result<AuthRoute, Error> = .success(.home)

    private(set) var fetchCallCount = 0
    private(set) var signOutCallCount = 0

    func restoreSession() async -> AuthRoute { .login }

    func signIn(with provider: AuthProvider) async throws -> AuthRoute { .home }

    func fetchConsentDefinitions() async throws -> [ConsentDefinition] {
        fetchCallCount += 1
        return definitions
    }

    func agreeToConsents(_ definitions: [ConsentDefinition]) async throws -> AuthRoute {
        try agreeResult.get()
    }

    func signOut() {
        signOutCallCount += 1
    }

    func deleteAccount() async throws {}
}

// MARK: - Fixtures

private extension ConsentDefinition {
    static func stub(_ type: ConsentType, version: String = "1.0") -> ConsentDefinition {
        ConsentDefinition(
            type: type,
            version: version,
            isRequired: true,
            policyUrl: URL(string: "https://nursemate.app/policy"),
            title: type == .terms ? "이용약관" : "개인정보처리방침"
        )
    }
}
