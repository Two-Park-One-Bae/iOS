//
//  PillDetailEnums.swift
//  Networks
//
//  Created by 바견규 on 7/16/26.
//

import Foundation

// GET /api/v0/pill-details 응답 전용 enum (domains/pill-detail.md).
// 서버가 새 케이스를 추가해도 앱이 크래시 나지 않도록 unknown 처리.

// 분류: 전문의약품(ETC) / 일반의약품(OTC)
public enum PillClassification: String, Codable {
    case etc = "ETC"
    case otc = "OTC"
    case unknown

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = PillClassification(rawValue: value) ?? .unknown
    }
}

// 허가문서 종류: 효능효과 / 용법용량 / 사용상 주의사항
public enum LicenseDocType: String, Codable {
    case effect  = "EFFECT"
    case dosage  = "DOSAGE"
    case caution = "CAUTION"
    case unknown

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = LicenseDocType(rawValue: value) ?? .unknown
    }
}

// 텍스트 첨자 스타일: 위첨자 / 아래첨자. 모르는 style은 일반 텍스트로 렌더.
public enum SpanStyle: String, Codable {
    case sup = "SUP"
    case sub = "SUB"
    case unknown

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = SpanStyle(rawValue: value) ?? .unknown
    }
}
