import XCTest
@testable import Domain

/// 진입 라우팅·동의·탈퇴 규칙 (NM-410).
///
/// 여기서 검증하는 건 전부 spec 이 "이렇게 되어야 한다"고 못박은 것들이다 —
/// 화면 분기의 근거(`onboardingRequired`), 탈퇴 실패 시 로그아웃 금지, 취소 시 캐시 폐기.
final class AuthUseCaseTests: XCTestCase {

    private var repository: MockAuthRepository!
    private var sut: DefaultAuthUseCase!

    override func setUp() {
        super.setUp()
        repository = MockAuthRepository()
        sut = DefaultAuthUseCase(repository: repository)
    }

    override func tearDown() {
        repository = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - 진입 라우팅

    func test_restoreSession_세션이없으면_로그인() async {
        repository.isSignedIn = false

        let route = await sut.restoreSession()

        XCTAssertEqual(route, .login)
        XCTAssertNil(sut.user.value)
        // 세션이 없으면 서버에 물어볼 것도 없다.
        XCTAssertEqual(repository.fetchMeCallCount, 0)
    }

    func test_restoreSession_동의미충족이면_동의온보딩() async {
        repository.isSignedIn = true
        repository.meResult = .success(.stub(onboardingRequired: true))

        let route = await sut.restoreSession()

        XCTAssertEqual(route, .consent)
    }

    func test_restoreSession_동의충족이면_홈() async {
        repository.isSignedIn = true
        repository.meResult = .success(.stub(onboardingRequired: false))

        let route = await sut.restoreSession()

        XCTAssertEqual(route, .home)
        XCTAssertEqual(sut.user.value?.userId, "uid")
    }

    /// 동의 여부를 모르는 채 홈에 들여보내면 "로그인됐지만 미동의" 상태가 화면에 생긴다.
    func test_restoreSession_회원조회실패면_로그인으로_되돌린다() async {
        repository.isSignedIn = true
        repository.meResult = .failure(AuthError.unknown)

        let route = await sut.restoreSession()

        XCTAssertEqual(route, .login)
        XCTAssertNil(sut.user.value)
    }

    // MARK: - 동의

    func test_agreeToConsents_필수항목전체를_현재버전으로_보낸다() async throws {
        repository.saveConsentsResult = .success(.stub(onboardingRequired: false))

        let route = try await sut.agreeToConsents([
            .stub(type: .terms, version: "1.2", isRequired: true),
            .stub(type: .privacy, version: "2.0", isRequired: true),
        ])

        XCTAssertEqual(route, .home)
        XCTAssertEqual(repository.savedAgreements.count, 2)
        XCTAssertTrue(repository.savedAgreements.allSatisfy(\.agreed))
        XCTAssertEqual(repository.savedAgreements.first(where: { $0.type == .terms })?.version, "1.2")
    }

    /// 저장에 성공했어도 서버가 아직 미충족이라 하면 화면에 남아야 한다.
    func test_agreeToConsents_응답이_미충족이면_동의화면에_머문다() async throws {
        repository.saveConsentsResult = .success(.stub(onboardingRequired: true))

        let route = try await sut.agreeToConsents([.stub(type: .terms, version: "1.0", isRequired: true)])

        XCTAssertEqual(route, .consent)
    }

    // MARK: - 로그아웃 · 탈퇴

    func test_signOut_계정정보를_비운다() async {
        repository.isSignedIn = true
        repository.meResult = .success(.stub(onboardingRequired: false))
        _ = await sut.restoreSession()
        XCTAssertNotNil(sut.user.value)

        sut.signOut()

        XCTAssertEqual(repository.signOutCallCount, 1)
        XCTAssertNil(sut.user.value)
    }

    /// 탈퇴가 실패했는데 로그아웃하면, 계정이 남아 있는데 삭제된 것처럼 보인다.
    func test_deleteAccount_실패하면_로그아웃하지_않는다() async {
        repository.isSignedIn = true
        repository.meResult = .success(.stub(onboardingRequired: false))
        _ = await sut.restoreSession()
        repository.deleteResult = .failure(AuthError.accountDeletionFailed)

        do {
            try await sut.deleteAccount()
            XCTFail("삭제 실패는 throw 되어야 한다")
        } catch {
            XCTAssertEqual(error as? AuthError, .accountDeletionFailed)
        }

        XCTAssertEqual(repository.signOutCallCount, 0)
        XCTAssertNotNil(sut.user.value)
    }

    func test_deleteAccount_성공하면_로그아웃하고_계정정보를_비운다() async throws {
        repository.isSignedIn = true
        repository.meResult = .success(.stub(onboardingRequired: false))
        _ = await sut.restoreSession()

        try await sut.deleteAccount()

        XCTAssertEqual(repository.signOutCallCount, 1)
        XCTAssertNil(sut.user.value)
    }
}

// MARK: - Mock

private final class MockAuthRepository: AuthRepositoryProtocol {

    var isSignedIn = false
    var meResult: Result<AuthUser, Error> = .failure(AuthError.unknown)
    var saveConsentsResult: Result<AuthUser, Error> = .failure(AuthError.unknown)
    var deleteResult: Result<Void, Error> = .success(())

    private(set) var fetchMeCallCount = 0
    private(set) var signOutCallCount = 0
    private(set) var savedAgreements: [ConsentAgreement] = []

    func signIn(with provider: AuthProvider) async throws {}

    func fetchMe() async throws -> AuthUser {
        fetchMeCallCount += 1
        return try meResult.get()
    }

    func fetchConsentDefinitions() async throws -> [ConsentDefinition] { [] }

    func saveConsents(_ agreements: [ConsentAgreement]) async throws -> AuthUser {
        savedAgreements = agreements
        return try saveConsentsResult.get()
    }

    func signOut() throws {
        signOutCallCount += 1
    }

    func deleteAccount() async throws {
        try deleteResult.get()
    }
}

// MARK: - Fixtures

private extension AuthUser {
    static func stub(onboardingRequired: Bool) -> AuthUser {
        AuthUser(
            userId: "uid",
            provider: .kakao,
            providerUserId: "kakao-1",
            consents: [],
            onboardingRequired: onboardingRequired
        )
    }
}

private extension ConsentDefinition {
    static func stub(type: ConsentType, version: String, isRequired: Bool) -> ConsentDefinition {
        ConsentDefinition(
            type: type,
            version: version,
            isRequired: isRequired,
            policyUrl: URL(string: "https://nursemate.app/policy"),
            title: "약관"
        )
    }
}
