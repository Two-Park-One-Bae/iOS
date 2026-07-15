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
    func fetchPillAttributes(request: PillAttributeRequest) -> AnyPublisher<[PillAttributeEntity], Error>
    func fetchPillCandidates(request: PillCandidateRequest) -> AnyPublisher<PillCandidatePageEntity, Error>
    func fetchPillDetail(pillCode: String) -> AnyPublisher<PillDetailEntity, Error>
}

extension DefaultPillService: PillService {
    public func fetchPillAttributes(request: PillAttributeRequest) -> AnyPublisher<[PillAttributeEntity], Error> {
        // 400(이미지 누락·언리더블 등) 에러 코드를 UI에서 분기할 수 있도록 WithNetworkError 버전 사용
        requestObjectWithNetworkErrorInCombine(.pillAttributes(request: request))
    }

    public func fetchPillCandidates(request: PillCandidateRequest) -> AnyPublisher<PillCandidatePageEntity, Error> {
        requestObjectInCombine(.pillCandidates(request: request))
    }

    public func fetchPillDetail(pillCode: String) -> AnyPublisher<PillDetailEntity, Error> {
        // 404(세부정보 없음)를 '세부정보 없음' 상태로 분기할 수 있도록 에러 코드를 보존하는 버전 사용 (NM-309)
        requestObjectWithNetworkErrorInCombine(.pillDetails(pillCode: pillCode))
    }
}
