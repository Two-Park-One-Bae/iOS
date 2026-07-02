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
    ) -> AnyPublisher<[PillAttributeModel], Error> {
        let requestItems = items.map {
            PillAttributeItemRequest(
                pillId: $0.pillId,
                segmentation: $0.segmentation,
                croppedImage: $0.croppedImage
            )
        }
        let request = PillAttributeRequest(originalImage: originalImage, items: requestItems)

        return service.fetchPillAttributes(request: request)
            .map { $0.map { $0.toDomain() } }
            .eraseToAnyPublisher()
    }

    public func fetchPillCandidates(
        colors: [PillColorModel]?,
        isTransparent: Bool?,
        shape: PillShapeModel?,
        formulation: PillFormulationModel?,
        front: PillFaceModel?,
        back: PillFaceModel?,
        page: Int,
        size: Int
    ) -> AnyPublisher<PillCandidatePageModel, Error> {
        // Domain 모델 → Network Request 모델 변환
        let request = PillCandidateRequest(
            colors: colors?.compactMap { $0.toNetwork() },
            isTransparent: isTransparent,
            shape: shape?.toNetwork(),
            formulation: formulation?.toNetwork(),
            front: front?.toNetwork(),
            back: back?.toNetwork(),
            page: page,
            size: size
        )

        return service.fetchPillCandidates(request: request)
            .map { $0.toDomain() }
            .eraseToAnyPublisher()
    }
}
