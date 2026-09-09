import XCTest

import Alamofire
import Moya

@testable import Networks

/// 서버에 닿지 못한 요청의 문구.
///
/// 예전엔 Moya 가 감싼 원문이 그대로 화면에 나갔다 — 분석 실패 화면에 실제로 이렇게 떴다:
/// "URLSessionTask failed with error: The Internet connection appears to be offline."
/// 한국어 앱에 영문 기술 문장이 노출되므로 `APIError.offline` 로 좁혀 사용자 문구를 붙인다.
final class OfflineErrorTests: XCTestCase {

    /// 실제로 오는 형태 — Moya(underlying) → AFError(sessionTaskFailed) → URLError.
    private func moyaOffline(_ code: URLError.Code) -> Error {
        let urlError = URLError(code)
        let afError = AFError.sessionTaskFailed(error: urlError)
        return MoyaError.underlying(afError, nil)
    }

    func test_연결없음은_offline로_해석된다() {
        let interpreted = BaseService<TestAPI>.interpret(moyaOffline(.notConnectedToInternet))

        XCTAssertEqual(interpreted as? APIError, .offline)
        XCTAssertEqual(interpreted.localizedDescription, "인터넷 연결을 확인해 주세요.")
    }

    /// 기내모드·Wi-Fi 끊김·셀룰러 차단 등 "닿지 못함" 계열은 모두 같은 안내로 모은다.
    func test_연결계열_코드들이_모두_offline() {
        let codes: [URLError.Code] = [
            .notConnectedToInternet, .networkConnectionLost,
            .cannotConnectToHost, .cannotFindHost,
            .dataNotAllowed, .internationalRoamingOff,
        ]

        for code in codes {
            XCTAssertEqual(
                BaseService<TestAPI>.interpret(moyaOffline(code)) as? APIError, .offline,
                "\(code) 는 서버에 닿지 못한 경우다"
            )
        }
    }

    /// 타임아웃은 연결은 됐는데 느린 것이라 "인터넷 연결을 확인하라"가 맞는 안내가 아니다.
    /// 원문을 그대로 두어 기존 경로(일반 문구)로 떨어뜨린다.
    func test_타임아웃은_offline이_아니다() {
        XCTAssertNotEqual(
            BaseService<TestAPI>.interpret(moyaOffline(.timedOut)) as? APIError, .offline
        )
    }
}

// MARK: - Fixtures

/// `interpret` 은 static 이라 Target 이 실제로 쓰이지 않는다 — 제네릭을 채우기 위한 최소 구현.
private enum TestAPI: TargetType {
    case ping

    var baseURL: URL { URL(string: "https://example.com")! }
    var path: String { "/ping" }
    var method: Moya.Method { .get }
    var task: Task { .requestPlain }
    var headers: [String: String]? { nil }
}
