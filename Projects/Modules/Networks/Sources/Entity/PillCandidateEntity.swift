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
    public let licenseStatus: String? // 허가상태 "NORMAL"|"REVOKED" (NM-337). 배지·후순위·세부정보 분기 기준
}

// POST /api/v0/pill-candidates 응답 (커서 페이지네이션, NM-158)
public struct PillCandidatePageEntity: Decodable {
    public let candidates: [PillCandidateEntity]
    public let nextCursor: String?   // 다음 페이지 커서. null이면 마지막 페이지
    public let hasNext: Bool
}
