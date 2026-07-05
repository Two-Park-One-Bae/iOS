//
//  PillCandidateEntity.swift
//  Networks
//
//  Created by 바견규 on 7/2/26.
//

import Foundation

// 후보 알약 1개. pillCode가 고유 ID이자 후보 선택 확정 키
public struct PillCandidateEntity: Decodable {
    public let pillCode: String
    public let pillName: String?
    public let companyName: String?   // 동명이약 구분
    public let pillImageUrl: String?  // 낱알 본체 이미지 (실물 시각 대조)
}

// POST /api/v0/pill-candidates 응답. 품목명 등 안정 정렬
public struct PillCandidatePageEntity: Decodable {
    public let candidates: [PillCandidateEntity]
    public let page: Int
    public let size: Int
    public let totalElements: Int
    public let totalPages: Int
}
