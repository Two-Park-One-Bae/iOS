//
//  PillFaceEntity.swift
//  Networks
//
//  Created by 바견규 on 7/2/26.
//

import Foundation

// 알약 한 면. 셋 다 선택적
public struct PillFaceEntity: Decodable {
    public let imprint: String?            // 각인. 없으면 null. 매칭은 정규화 후 substring·면무관
    public let dividingLine: DividingLine? // 구분선. 각인 텍스트에서 파생
    public let hasMark: Bool?              // 마크 유무. MVP는 유무만 체크 (상세는 V1+)

    enum CodingKeys: String, CodingKey {
        case imprint, dividingLine, hasMark
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.imprint      = try container.decodeIfPresent(String.self, forKey: .imprint)
        self.dividingLine = try container.decodeIfPresent(DividingLine.self, forKey: .dividingLine)
        self.hasMark      = try container.decodeIfPresent(Bool.self, forKey: .hasMark)
    }
}
