//
//  PillDetailError.swift
//  Domain
//
//  Created by 바견규 on 7/21/26.
//

import Foundation

/// 세부정보 없음 (404 `PILL_DETAIL_NOT_FOUND`, NM-309).
///
/// 오류가 아니라 '세부정보 없음' 상태로 렌더해야 해서, 일반 오류와 구분해 타입으로 올린다.
/// (문자열 localizedDescription에는 상태코드·code가 남지 않아 문자열 매칭으로는 판별 불가.)
public struct PillDetailNotFoundError: Error {
    public init() {}
}
