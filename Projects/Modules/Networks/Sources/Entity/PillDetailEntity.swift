//
//  PillDetailEntity.swift
//  Networks
//
//  Created by 바견규 on 7/16/26.
//

import Foundation

// GET /api/v0/pill-details/{pillCode} 응답 (NM-312).
// 허가문서 원문(XML+HTML)을 서버가 구조화한 블록 모델. 클라이언트는 파싱 없이 렌더만 한다.
public struct PillDetailEntity: Decodable {
    public let pillCode: String
    public let name: String
    public let companyName: String            // 동명이약 구분
    public let classification: PillClassification
    public let appearance: String?            // 성상 — 색·모양·제형 서술
    public let ingredients: [IngredientEntity]
    public let storageMethod: String?
    public let validTerm: String?
    public let packUnit: String?
    public let documents: [LicenseDocEntity]   // type당 최대 1개·누락 가능. 순서 아닌 type으로 찾는다.
}

// 유효성분 1개
public struct IngredientEntity: Decodable {
    public let name: String
    public let amount: String    // 표기가 다양(소수·범위 등)해 문자열
    public let unit: String
}

// 허가문서 1개 (효능효과/용법용량/주의사항)
public struct LicenseDocEntity: Decodable {
    public let type: LicenseDocType
    public let blocks: [BlockEntity]   // 문서 순서 그대로
}

// 문서 블록 — type 디스크리미네이터 기반 다형성. 모르는 type은 .unknown (렌더 시 skip).
public enum BlockEntity: Decodable {
    case heading(content: [SpanEntity])
    case paragraph(content: [SpanEntity])
    case table(caption: [SpanEntity]?, rows: [TableRowEntity])
    case image(src: String)
    case unknown

    private enum CodingKeys: String, CodingKey {
        case type, content, caption, rows, src
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "HEADING":
            self = .heading(content: try container.decode([SpanEntity].self, forKey: .content))
        case "PARAGRAPH":
            self = .paragraph(content: try container.decode([SpanEntity].self, forKey: .content))
        case "TABLE":
            self = .table(
                caption: try container.decodeIfPresent([SpanEntity].self, forKey: .caption),
                rows: try container.decode([TableRowEntity].self, forKey: .rows)
            )
        case "IMAGE":
            self = .image(src: try container.decode(String.self, forKey: .src))
        default:
            self = .unknown   // 호환성: 모르는 블록 타입은 건너뛴다
        }
    }
}

// 표 행
public struct TableRowEntity: Decodable {
    public let cells: [TableCellEntity]
}

// 표 셀 — 병합 시맨틱은 HTML 표와 동일(병합 슬롯은 왼쪽 위에 한 번만).
public struct TableCellEntity: Decodable {
    public let content: [SpanEntity]   // 빈 셀은 []
    public let colspan: Int
    public let rowspan: Int
    public let header: Bool

    private enum CodingKeys: String, CodingKey {
        case content, colspan, rowspan, header
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.content = try container.decode([SpanEntity].self, forKey: .content)
        self.colspan = try container.decodeIfPresent(Int.self, forKey: .colspan) ?? 1
        self.rowspan = try container.decodeIfPresent(Int.self, forKey: .rowspan) ?? 1
        self.header  = try container.decodeIfPresent(Bool.self, forKey: .header) ?? false
    }
}

// 텍스트 조각 — 순수 문자열(HTML 태그·엔티티 없음). style 없으면 일반 텍스트.
public struct SpanEntity: Decodable {
    public let text: String
    public let style: SpanStyle?
}
