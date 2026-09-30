//
//  PillRepositoryInterface.swift
//  Domain
//
//  Created by 바견규 on 7/2/26.
//

import Combine
import Foundation

public protocol PillRepositoryProtocol {
    // 크롭 이미지 → 속성 토큰 + 표시값 추출 (서버 /api/v1, NM-487 · NM-521). 원본은 별도 S3 업로드(NM-348)
    // 한도 도달 시 PillLimitExceededError로 실패한다 (429 LIMIT_EXCEEDED · 미차감)
    func fetchPillAttributes(
        items: [(pillId: String, croppedImage: String)]
    ) -> AnyPublisher<PillAttributeResultModel, Error>

    // 수정 속성 → 후보 조회 (서버 /api/v1, NM-488). 정렬된 ids(≤200) + 앞 20개 상세.
    // 서버가 속성 토큰을 해석 못 하면 PillInvalidAttributeTokenError.
    func fetchPillCandidates(query: PillCandidateQuery) -> AnyPublisher<PillCandidateResultModel, Error>

    // ids 다음 구간의 후보 카드(1~50개, NM-489). 순서는 보장하지 않는다.
    func fetchPillCandidateItems(pillCodes: [String]) -> AnyPublisher<PillCandidateItemsModel, Error>

    // 학습데이터용 원본 이미지를 S3에 직접 업로드 (NM-348). 식별과 분리된 베스트 에포트 —
    // 실패해도 식별 플로우에 영향 없다. presigned URL 발급 → S3 PUT까지 수행한다.
    func uploadOriginalImage(_ jpegData: Data) -> AnyPublisher<Void, Error>

    // pillCode → 알약 세부정보 조회 (NM-312)
    func fetchPillDetail(pillCode: String) -> AnyPublisher<PillDetailModel, Error>

    // 잔여 식별 횟수 조회 (NM-331). 조회 전용 — 카운트가 늘지 않는다
    func fetchPillUsage() -> AnyPublisher<PillUsageModel, Error>
}
