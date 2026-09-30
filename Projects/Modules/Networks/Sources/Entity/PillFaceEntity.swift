//
//  PillFaceEntity.swift
//  Networks
//
//  Created by 바견규 on 7/2/26.
//

import Foundation

// 후보 카드의 면 정보 (spec PillCandidateFace, NM-488). 넷 다 선택적
public struct PillFaceEntity: Decodable {
    public let imprint: String?            // 각인. 없으면 null
    public let dividingLine: DividingLine? // 구분선. 각인 텍스트에서 파생 (NONE = 없음)
    public let hasMark: Bool?              // 마크 유무
    public let markCode: String?           // 식약처 마크 코드(r0062 형식) — 표시용, 검색에 쓰지 않는다
}
