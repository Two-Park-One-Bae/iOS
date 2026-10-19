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
    // 정렬된 ids + 앞 20개 상세 (NM-488). 400 INVALID_ATTRIBUTE_TOKEN 분기를 위해 에러 코드를 보존한다.
    func fetchPillCandidates(request: PillCandidateRequest) -> AnyPublisher<PillCandidateResultEntity, Error>
    // ids 다음 구간의 후보 카드(1~50개, NM-489)
    func fetchPillCandidateItems(pillCodes: [String]) -> AnyPublisher<PillCandidateItemsEntity, Error>
    func fetchPillDetail(pillCode: String) -> AnyPublisher<PillDetailEntity, Error>
    func fetchPillUsage() -> AnyPublisher<PillUsageEntity, Error>
    // 원본 이미지 S3 업로드용 presigned URL 발급 (NM-348). 식별과 분리된 베스트 에포트.
    func issuePillImageUploadURL() -> AnyPublisher<PillImageUploadURLEntity, Error>
    // 식별 기록 요약 목록, 최신순 (NM-552)
    func fetchPillHistories(limit: Int, cursor: String?) -> AnyPublisher<PillHistoryPageEntity, Error>
    func fetchPillHistory(historyId: String) -> AnyPublisher<PillHistoryEntity, Error>
    func savePillHistory(historyId: String, pillCodes: [String]) -> AnyPublisher<Void, Error>
    func deletePillHistory(historyId: String) -> AnyPublisher<Void, Error>
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

    public func fetchPillHistories(limit: Int, cursor: String?) -> AnyPublisher<PillHistoryPageEntity, Error> {
        requestObjectWithNetworkErrorInCombine(.pillHistories(limit: limit, cursor: cursor))
    }

    // 404(없어진 기록)를 Repository 가 구분할 수 있도록 에러 코드를 보존한다.
    public func fetchPillHistory(historyId: String) -> AnyPublisher<PillHistoryEntity, Error> {
        requestObjectWithNetworkErrorInCombine(.pillHistory(historyId: historyId))
    }

    // 204. 400(카탈로그에 없는 pillCode)은 다시 시도하지 않으므로 상태코드를 보존한다.
    public func savePillHistory(historyId: String, pillCodes: [String]) -> AnyPublisher<Void, Error> {
        requestNoContentWithNetworkErrorInCombine(
            .savePillHistory(historyId: historyId, request: PillHistorySaveRequest(pillCodes: pillCodes))
        )
    }

    public func deletePillHistory(historyId: String) -> AnyPublisher<Void, Error> {
        requestNoContentWithNetworkErrorInCombine(.deletePillHistory(historyId: historyId))
    }

    // 400 INVALID_ATTRIBUTE_TOKEN 을 Repository 가 구분할 수 있도록 에러 코드를 보존한다 (NM-488)
    public func fetchPillCandidates(request: PillCandidateRequest) -> AnyPublisher<PillCandidateResultEntity, Error> {
        requestObjectWithNetworkErrorInCombine(.pillCandidates(request: request))
    }

    public func fetchPillCandidateItems(pillCodes: [String]) -> AnyPublisher<PillCandidateItemsEntity, Error> {
        requestObjectWithNetworkErrorInCombine(.pillCandidateItems(pillCodes: pillCodes))
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
