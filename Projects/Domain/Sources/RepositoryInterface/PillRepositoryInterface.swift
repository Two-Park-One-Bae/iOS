//
//  PillRepositoryInterface.swift
//  Domain
//
//  Created by 바견규 on 7/2/26.
//

import Combine
import Foundation

public protocol PillRepositoryProtocol {
    // 크롭 이미지 → 색·모양·제형 추출 (원본은 별도 S3 업로드, NM-348)
    // 한도 도달 시 PillLimitExceededError로 실패한다 (429 LIMIT_EXCEEDED · 미차감)
    func fetchPillAttributes(
        items: [(pillId: String, croppedImage: String)]
    ) -> AnyPublisher<PillAttributeResultModel, Error>

    // 수정 속성 → 후보 알약 조회
    func fetchPillCandidates(
        colors: [PillColorModel]?,
        isTransparent: Bool?,
        shape: PillShapeModel?,
        formulation: PillFormulationModel?,
        front: PillFaceModel?,
        back: PillFaceModel?,
        cursor: String?,
        size: Int
    ) -> AnyPublisher<PillCandidatePageModel, Error>

    // pillCode → 알약 세부정보 조회 (NM-312)
    func fetchPillDetail(pillCode: String) -> AnyPublisher<PillDetailModel, Error>

    // 잔여 식별 횟수 조회 (NM-331). 조회 전용 — 카운트가 늘지 않는다
    func fetchPillUsage() -> AnyPublisher<PillUsageModel, Error>
}
