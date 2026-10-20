//
//  PillLabelRepository.swift
//  Data
//

import Combine
import Foundation

import Domain
import Networks

public final class PillLabelRepository: PillLabelRepositoryProtocol {
    private let service: PillService

    public init(service: PillService) {
        self.service = service
    }

    public func saveLabel(imageId: String, pillIndex: Int, label: PillLabelModel) -> AnyPublisher<Void, Error> {
        // model · userInput 은 후보 조회 요청 본문 그대로다 — 같은 변환을 쓴다.
        let request = PillLabelRequest(
            pillCode: label.pillCode,
            manual: label.manual,
            model: label.model?.toNetwork(),
            userInput: label.userInput.toNetwork()
        )
        return service.savePillLabel(imageId: imageId, pillIndex: pillIndex, request: request)
    }

    public func saveDeletedIndexes(imageId: String, deletedIndexes: [Int]) -> AnyPublisher<Void, Error> {
        service.savePillSegmentation(imageId: imageId, deletedIndexes: deletedIndexes)
    }
}
