import XCTest
@testable import Networks

/// Bearer 를 붙일 경로와 붙이지 않을 경로 (NM-410).
///
/// 서버의 permitAll 목록과 정확히 같아야 한다 — 여기가 어긋나면 공개 엔드포인트에 토큰이 붙거나
/// (미로그인 시 로그인 자체가 막힌다), 인증 엔드포인트에 토큰이 빠져 전부 401 이 된다.
final class APIRequestInterceptorTests: XCTestCase {

    func test_공개엔드포인트는_Bearer를_붙이지_않는다() {
        let publicPaths = [
            "/actuator/health",
            "/health",
            "/api/v0/auth/kakao/token",
            "/api/v0/consents",
        ]

        for path in publicPaths {
            XCTAssertFalse(
                APIRequestInterceptor.requiresAuthorization(request(path)),
                "\(path) 는 공개 엔드포인트다 (spec: domains/auth.md §방식)"
            )
        }
    }

    func test_그외_모든_경로는_Bearer가_필요하다() {
        let authenticatedPaths = [
            "/api/v0/users/me",
            // 접두가 같아도 별개 경로다 — prefix 매칭으로 느슨하게 열리면 안 된다.
            "/api/v0/users/me/consents",
            "/api/v0/pill-attributes",
            "/api/v0/pill-attributes/usage",
            "/api/v0/pill-candidates",
        ]

        for path in authenticatedPaths {
            XCTAssertTrue(
                APIRequestInterceptor.requiresAuthorization(request(path)),
                "\(path) 는 인증이 필요하다"
            )
        }
    }

    /// 공개 경로와 접두가 겹치는 하위 경로가 실수로 열리면 안 된다.
    func test_공개경로의_하위경로는_공개가_아니다() {
        XCTAssertTrue(APIRequestInterceptor.requiresAuthorization(request("/api/v0/consents/history")))
    }

    private func request(_ path: String) -> URLRequest {
        URLRequest(url: URL(string: "https://dev.nursemate.app\(path)")!)
    }
}
