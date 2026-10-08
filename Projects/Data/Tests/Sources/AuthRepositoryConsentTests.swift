import XCTest

@testable import Data
import Domain
import Networks

/// 동의 정의의 모르는 항목 처리 (NM-548, spec: domains/auth.md §선택 동의 "모르는 항목").
///
/// 모르는 **선택** 항목은 버려도 앱이 막히지 않지만, 모르는 **필수** 항목을 버리면 그 항목을 빼고
/// 저장해 `onboardingRequired` 가 끝내 풀리지 않는다 — 그때는 업데이트를 안내해야 한다.
final class AuthRepositoryConsentTests: XCTestCase {

    func test_모르는_선택항목은_버린다() async throws {
        let sut = AuthRepository(service: StubAuthService(definitions: [
            .stub("TERMS", required: true),
            .stub("MARKETING", required: false),
        ]))

        let definitions = try await sut.fetchConsentDefinitions()

        XCTAssertEqual(definitions.map(\.type), [.terms])
    }

    func test_모르는_필수항목이면_업데이트를_요구한다() async {
        let sut = AuthRepository(service: StubAuthService(definitions: [
            .stub("TERMS", required: true),
            .stub("NEW_REQUIRED", required: true),
        ]))

        do {
            _ = try await sut.fetchConsentDefinitions()
            XCTFail("모르는 필수 항목을 버리고 진행하면 안 된다")
        } catch {
            XCTAssertEqual(error as? AuthError, .updateRequired)
        }
    }
}

private struct StubAuthService: AuthService {
    let definitions: [ConsentDefinitionEntity]

    func exchangeKakaoToken(_ accessToken: String) async throws -> KakaoTokenEntity { throw AuthError.unknown }
    func fetchConsentDefinitions() async throws -> [ConsentDefinitionEntity] { definitions }
    func fetchMe() async throws -> UserEntity { throw AuthError.unknown }
    func saveConsents(_ agreements: [ConsentAgreementRequest]) async throws -> UserEntity { throw AuthError.unknown }
    func deleteMe() async throws {}
}

private extension ConsentDefinitionEntity {
    static func stub(_ type: String, required: Bool) -> ConsentDefinitionEntity {
        let json = #"{"type":"\#(type)","version":"1.0","required":\#(required),"policyUrl":"https://nursemate.app/p","title":"t"}"#
        return try! JSONDecoder().decode(ConsentDefinitionEntity.self, from: Data(json.utf8))
    }
}
