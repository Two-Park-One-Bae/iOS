//
//  PillService.swift
//  Networks
//
//  Created by 바견규 on 7/2/26.
//

import Combine
import Foundation

// BaseService<PillAPI>의 타입 별칭. DI 등록 시 DefaultPillService.standard로 사용
public typealias DefaultPillService = BaseService<PillAPI>

// Repository가 의존할 프로토콜. 테스트 시 Mock으로 교체 가능
public protocol PillService {
    func fetchPillAttributes(request: PillAttributeRequest) -> AnyPublisher<PillAttributeResponseEntity, Error>
    func fetchPillCandidates(request: PillCandidateRequest) -> AnyPublisher<PillCandidatePageEntity, Error>
    func fetchPillDetail(pillCode: String) -> AnyPublisher<PillDetailEntity, Error>
    func fetchPillUsage() -> AnyPublisher<PillUsageEntity, Error>
    // 원본 이미지 S3 업로드용 presigned URL 발급 (NM-348). 식별과 분리된 베스트 에포트.
    func issuePillImageUploadURL() -> AnyPublisher<PillImageUploadURLEntity, Error>
}

extension DefaultPillService: PillService {
    public func fetchPillAttributes(request: PillAttributeRequest) -> AnyPublisher<PillAttributeResponseEntity, Error> {
        // 400(이미지 누락·언리더블 등)·429(한도 도달) 에러 코드를 UI에서 분기할 수 있도록 WithNetworkError 버전 사용
        requestObjectWithNetworkErrorInCombine(.pillAttributes(request: request))
    }

    // 조회 전용 — 호출해도 카운트가 늘지 않는다 (NM-331)
    public func fetchPillUsage() -> AnyPublisher<PillUsageEntity, Error> {
        requestObjectWithNetworkErrorInCombine(.pillAttributesUsage)
    }

    public func fetchPillCandidates(request: PillCandidateRequest) -> AnyPublisher<PillCandidatePageEntity, Error> {
        requestObjectInCombine(.pillCandidates(request: request))
    }

    // 발급 실패(401·500)는 베스트 에포트라 상위에서 무시된다 — 일반 요청 헬퍼로 충분.
    public func issuePillImageUploadURL() -> AnyPublisher<PillImageUploadURLEntity, Error> {
        requestObjectInCombine(.pillImagesUploadUrl)
    }

    public func fetchPillDetail(pillCode: String) -> AnyPublisher<PillDetailEntity, Error> {
        // 404(세부정보 없음)를 '세부정보 없음' 상태로 분기할 수 있도록 에러 코드를 보존하는 버전 사용 (NM-309)
        requestObjectWithNetworkErrorInCombine(.pillDetails(pillCode: pillCode))
    }
}
