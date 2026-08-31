//
//  Error.swift
//  Networks
//
//  Created by 바견규 on 7/2/26.
//

import Foundation

public struct NetworkError: Decodable, Error {
    public let type: String
    public let title: String
    public let status: Int
    public let detail: String
    public let instance: String?
    public let code: String?

    /// 응답 원문. RFC 9457은 표준 필드 외 **확장 멤버**를 허용하는데(예: 429 LIMIT_EXCEEDED의 `usage`),
    /// 도메인별 확장 필드를 이 Foundation 타입이 알 필요는 없으므로 원문만 들고 있다가
    /// 필요한 계층(Repository)에서 직접 decode 한다. 디코딩 대상이 아니라 decode 후 주입한다.
    public var rawBody: Data?

    enum CodingKeys: String, CodingKey {
        case type, title, status, detail, instance, code
    }
}

public enum APIError: Error, Equatable {
    case network(statusCode: Int, error: NetworkError)
    case unknown
    case tokenReissuanceFailed

    public static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown):                             return true
        case (.tokenReissuanceFailed, .tokenReissuanceFailed): return true
        case (.network(let ls, _), .network(let rs, _)):       return ls == rs
        default:                                               return false
        }
    }
}

/// 화면에 그대로 띄울 문구.
///
/// 화면 대부분은 `error.localizedDescription` 을 받아 그대로 보여 준다
/// (`PillUseCase.errorMessage` → 분석 실패 화면). `LocalizedError` 를 채택하지 않으면
/// 시스템 기본 문구 — "The operation couldn't be completed. (Networks.APIError error 1.)" —
/// 가 사용자에게 그대로 간다.
///
/// **서버의 `detail` 을 그대로 쓰지 않는다.** 영문인 데다, 분기는 `detail` 이 아니라 `code` 로
/// 한다는 게 규약이다 (spec: domains/errors.md §규약 · `AuthErrorMapper` 와 같은 원칙).
///
/// 여기 없는 코드·상태는 일반 문구로 떨어뜨린다. 원인을 정확히 말하는 것보다,
/// **사용자가 다음에 뭘 하면 되는지**를 알려 주는 게 목적이다.
extension APIError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .network(let statusCode, let problem):
            return Self.message(statusCode: statusCode, code: problem.code)
        case .tokenReissuanceFailed:
            return "로그인이 만료됐어요. 다시 로그인해 주세요."
        case .unknown:
            return Self.generic
        }
    }

    private static let generic = "일시적인 오류가 발생했어요. 잠시 후 다시 시도해 주세요."

    private static func message(statusCode: Int, code: String?) -> String {
        switch (statusCode, code) {
        case (_, "APP_CHECK_FAILED"):
            // 앱 무결성 검증 실패. **사용자가 할 수 있는 일이 사실상 없다** — 원인이 기기 쪽일
            // 수도, 서버 설정 불일치일 수도 있다(실제로 후자로 났다).
            //
            // 그래서 "다시 로그인"도 "앱 업데이트"도 안내하지 않는다. 로그인으로는 안 풀리고,
            // 업데이트는 대개 받을 게 없어 App Store 앞에서 막힌다 — **할 수 없는 일을 시키는
            // 안내가 아무 안내보다 나쁘다.** 재시도만 권하고, 반복되면 문의로 넘긴다.
            return "앱 인증에 실패했어요. 잠시 후 다시 시도해 주세요."
        case (401, _):
            return "로그인이 필요해요. 다시 로그인해 주세요."
        case (503, _):
            // 일시 장애 — 세션은 유지된다. 재시도만 안내한다.
            return "서비스가 일시적으로 불안정해요. 잠시 후 다시 시도해 주세요."
        default:
            return generic
        }
    }
}
