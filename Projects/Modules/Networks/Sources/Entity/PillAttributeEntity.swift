//
//  PillAttributeEntity.swift
//  Networks
//
//  Created by 바견규 on 7/2/26.
//

import Foundation

// POST /api/v0/pill-attributes 응답 아이템. pillId 기준으로 요청과 매핑
public struct PillAttributeEntity: Decodable {
    public let pillId: String
    public let colors: [PillColor]?       // 추출 실패 시 null → 사용자 선택
    public let isTransparent: Bool        // 투명 여부. 색조와 분리된 축. 기본값 false
    public let shape: PillShape?
    public let formulation: PillFormulation?
    public let front: PillFaceEntity?     // MVP: 수동입력이라 항상 null
    public let back: PillFaceEntity?      // MVP: 수동입력이라 항상 null
    public let error: String?             // 개별 알약 추출 실패 시 에러 코드. 성공 시 null

    enum CodingKeys: String, CodingKey {
        case pillId, colors, isTransparent, shape, formulation, front, back, error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pillId        = try container.decode(String.self, forKey: .pillId)
        self.colors        = try container.decodeIfPresent([PillColor].self, forKey: .colors)
        self.isTransparent = try container.decodeIfPresent(Bool.self, forKey: .isTransparent) ?? false
        self.shape         = try container.decodeIfPresent(PillShape.self, forKey: .shape)
        self.formulation   = try container.decodeIfPresent(PillFormulation.self, forKey: .formulation)
        self.front         = try container.decodeIfPresent(PillFaceEntity.self, forKey: .front)
        self.back          = try container.decodeIfPresent(PillFaceEntity.self, forKey: .back)
        self.error         = try container.decodeIfPresent(String.self, forKey: .error)
    }
}
