//
//  PillRepository.swift
//  Data
//
//  Created by 바견규 on 7/2/26.
//

import Combine
import Foundation

import Domain
import Networks

public final class PillRepository: PillRepositoryProtocol {
    private let service: PillService

    public init(service: PillService) {
        self.service = service
    }

    public func fetchPillAttributes(
        originalImage: String,
        items: [(pillId: String, segmentation: [[Double]], croppedImage: String)]
    ) -> AnyPublisher<PillAttributeResultModel, Error> {
        // OpenAPI 스키마에 맞춰 감싼다: 이미지 → {mimeType, data}, 폴리곤 → {type, points}.
        // 원본은 jpeg, 크롭 썸네일은 png 로 인코딩됨(ViewModel 기준).
        let requestItems = items.map {
            PillAttributeItemRequest(
                pillId: $0.pillId,
                segmentation: SegmentationRequest(type: "POLYGON", points: $0.segmentation),
                croppedImage: PillImageRequest(mimeType: "image/png", data: $0.croppedImage)
            )
        }
        let request = PillAttributeRequest(
            originalImage: PillImageRequest(mimeType: "image/jpeg", data: originalImage),
            items: requestItems
        )

        return service.fetchPillAttributes(request: request)
            .map { $0.toDomain() }
            .mapError { Self.mapLimitExceeded($0) }
            .eraseToAnyPublisher()
    }

    public func fetchPillUsage() -> AnyPublisher<PillUsageModel, Error> {
        service.fetchPillUsage()
            .map { $0.toDomain() }
            .eraseToAnyPublisher()
    }

    /// 429 `LIMIT_EXCEEDED`만 UI가 '한도 안내 팝업'으로 분기할 수 있도록 도메인 에러로 올린다.
    /// 나머지는 그대로 통과 — 일반 오류 처리 경로를 바꾸지 않는다.
    private static func mapLimitExceeded(_ error: Error) -> Error {
        guard case APIError.network(let statusCode, let problem) = error, statusCode == 429 else {
            return error
        }

        // usage는 RFC 9457 확장 멤버라 NetworkError에 없다 — 보존해둔 원문에서 꺼낸다.
        let usage = problem.rawBody
            .flatMap { try? JSONDecoder().decode(PillLimitExceededEntity.self, from: $0) }
            .map { $0.usage.toDomain() }

        return PillLimitExceededError(usage: usage)
    }

    public func fetchPillCandidates(
        colors: [PillColorModel]?,
        isTransparent: Bool?,
        shape: PillShapeModel?,
        formulation: PillFormulationModel?,
        front: PillFaceModel?,
        back: PillFaceModel?,
        cursor: String?,
        size: Int
    ) -> AnyPublisher<PillCandidatePageModel, Error> {
        // Domain 모델 → Network Request 모델 변환. colors는 required·non-null(nil이면 빈 배열).
        let request = PillCandidateRequest(
            colors: colors?.compactMap { $0.toNetwork() } ?? [],
            isTransparent: isTransparent,
            shape: shape?.toNetwork(),
            formulation: formulation?.toNetwork(),
            front: front?.toNetwork(),
            back: back?.toNetwork(),
            cursor: cursor,
            size: size
        )

        return service.fetchPillCandidates(request: request)
            .map { $0.toDomain() }
            .eraseToAnyPublisher()
    }

    public func fetchPillDetail(pillCode: String) -> AnyPublisher<PillDetailModel, Error> {
        service.fetchPillDetail(pillCode: pillCode)
            .map { $0.toDomain() }
            .eraseToAnyPublisher()
    }
}
