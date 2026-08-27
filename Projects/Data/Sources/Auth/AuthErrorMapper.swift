//
//  AuthErrorMapper.swift
//  Data
//
//  Created by 바견규 on 8/28/26.
//

import Foundation

import Domain
import Networks

/// 네트워크 에러를 화면이 다르게 반응해야 하는 `AuthError` 로만 좁힌다.
///
/// 분기는 `detail` 문구가 아니라 **`code`** 로 한다 — `detail` 은 계약이 아니라 언제든 바뀐다
/// (spec: domains/errors.md §규약). 목록에 없는 code 는 HTTP status 로 폴백한다.
enum AuthErrorMapper {

    static func map(_ error: Error) -> AuthError {
        // 이미 도메인 에러면 그대로 통과 — 소셜 SDK 취소 등이 여기로 온다.
        if let authError = error as? AuthError { return authError }

        guard case APIError.network(let statusCode, let problem) = error else {
            return .unknown
        }

        switch (statusCode, problem.code) {
        case (401, "KAKAO_TOKEN_INVALID"):
            return .kakaoTokenInvalid
        case (503, _):
            // 일시 장애 — 세션을 유지하고 재시도만 안내한다. 로그아웃 사유가 아니다.
            return .serviceUnavailable
        default:
            return .unknown
        }
    }

    /// 동의 저장 전용. 여기서만 400 이 "약관 버전이 바뀌었다"는 뜻을 갖는다
    /// — 화면은 오류로 끝내지 않고 `GET /consents` 를 재조회해 새 버전으로 다시 그린다.
    ///
    /// 같은 400 이라도 카카오 교환에서는 요청 형식 오류(INVALID_REQUEST)라 의미가 다르므로,
    /// 공통 `map` 에 넣지 않고 호출 맥락이 있는 이 자리에서만 해석한다.
    static func mapConsentSave(_ error: Error) -> AuthError {
        if case APIError.network(400, _) = error { return .consentVersionMismatch }
        return map(error)
    }
}
