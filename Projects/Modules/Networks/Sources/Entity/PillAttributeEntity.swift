//
//  PillAttributeEntity.swift
//  Networks
//
//  Created by 바견규 on 7/2/26.
//

import Foundation

/// POST /api/v1/pill-attributes 응답 아이템. pillId 기준으로 요청과 매핑 (NM-487 · NM-521).
///
/// 색 이름 · 투명 · 면 정보는 없고, 모델 출력은 **속성 토큰**으로 받는다.
/// `error` 가 nil 이면 나머지 넷이 모두 채워진다 — 속성별 부분 실패는 없다(spec PillAttribute).
public struct PillAttributeEntity: Decodable {
    public let pillId: String
    /// 서버가 인코딩한 불투명 문자열. 앱은 해석하지 않고 후보 조회에 그대로 돌려준다.
    /// 한 식별 흐름 안에서만 쓴다 — 앱 재실행 너머로 보관하지 않는다.
    public let attributeToken: String?
    /// 모델 색의 표시값(sRGB `#RRGGBB`, 다색이면 여러 개). 검색에는 쓰지 않고 표시·되돌리기용.
    public let colorHexes: [String]?
    /// 대표 모양(SEMICIRCLE 제외 10종). 표시·되돌리기용 — 후보 조회 조건으로 보내지 않는다.
    public let shape: PillShape?
    /// 대표 제형(OTHER 제외 3종). 표시·되돌리기용 — 후보 조회 조건으로 보내지 않는다.
    public let formulation: PillFormulation?
    /// 알약 통째 추출 실패 시 `EXTRACTION_FAILED`.
    public let error: String?
}
