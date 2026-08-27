import XCTest

@testable import Data
import Domain
import Networks

/// 동의 정의 매핑 (NM-409).
///
/// `policyUrl` 은 서버가 주는 값이라 앱이 검증해야 한다 — 못 여는 URL 을
/// `SFSafariViewController` 에 넘기면 예외로 앱이 죽는다.
final class AuthMapperTests: XCTestCase {

    func test_http_https_문서_URL은_통과한다() {
        for raw in ["https://nursemate.app/policy/terms", "http://nursemate.app/policy/terms"] {
            XCTAssertNotNil(definition(policyUrl: raw)?.policyUrl, raw)
        }
    }

    /// URL(string:) 은 스킴 없는 문자열도 nil 이 아닌 URL 로 만들어 준다 —
    /// 존재 검사만으로는 걸러지지 않아 여기서 잘라야 한다.
    func test_스킴이_없으면_문서_URL로_보지_않는다() {
        XCTAssertNotNil(URL(string: "nursemate.app/policy/terms"), "전제: URL(string:) 은 이걸 통과시킨다")
        XCTAssertNil(definition(policyUrl: "nursemate.app/policy/terms")?.policyUrl)
    }

    func test_웹이_아닌_스킴은_문서_URL로_보지_않는다() {
        for raw in ["file:///etc/passwd", "javascript:alert(1)", "nursemate://policy"] {
            XCTAssertNil(definition(policyUrl: raw)?.policyUrl, raw)
        }
    }

    func test_모르는_동의항목은_버린다() {
        XCTAssertNil(definition(type: "MARKETING"))
    }

    // MARK: - Helper

    private func definition(type: String = "TERMS", policyUrl: String) -> ConsentDefinition? {
        decode(type: type, policyUrl: policyUrl).toDomain()
    }

    private func definition(type: String) -> ConsentDefinition? {
        decode(type: type, policyUrl: "https://nursemate.app/policy/terms").toDomain()
    }

    private func decode(type: String, policyUrl: String) -> ConsentDefinitionEntity {
        let json = """
        {"type":"\(type)","version":"1.0","required":true,"policyUrl":"\(policyUrl)","title":"이용약관"}
        """
        return try! JSONDecoder().decode(ConsentDefinitionEntity.self, from: Data(json.utf8))
    }
}
