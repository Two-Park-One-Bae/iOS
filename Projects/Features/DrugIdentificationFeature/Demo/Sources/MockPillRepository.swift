//
//  MockPillRepository.swift
//  DrugIdentificationFeatureDemo
//
//  Created by 바견규 on 7/5/26.
//

import Combine
import Foundation

import Domain

final class MockPillRepository: PillRepositoryProtocol {

    func fetchPillAttributes(
        originalImage: String,
        items: [(pillId: String, segmentation: [[Double]], croppedImage: String)]
    ) -> AnyPublisher<[PillAttributeModel], Error> {
        let stub = items.map { item in
            PillAttributeModel(
                pillId:        item.pillId,
                colors:        [.white, .yellow],
                isTransparent: false,
                shape:         .oval,
                formulation:   .tablet,
                front:         PillFaceModel(imprint: "ABC", dividingLine: .minus, hasMark: false),
                back:          PillFaceModel(imprint: nil, dividingLine: nil, hasMark: false),
                error:         nil
            )
        }
        return Just(stub)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func fetchPillCandidates(
        colors: [PillColorModel]?,
        isTransparent: Bool?,
        shape: PillShapeModel?,
        formulation: PillFormulationModel?,
        front: PillFaceModel?,
        back: PillFaceModel?,
        page: Int,
        size: Int
    ) -> AnyPublisher<PillCandidatePageModel, Error> {
        let stub = PillCandidatePageModel(
            candidates: [
                PillCandidateModel(
                    pillCode:     "A11A1234",
                    pillName:     "타이레놀정500밀리그람",
                    companyName:  "한국얀센",
                    pillImageUrl: nil
                ),
                PillCandidateModel(
                    pillCode:     "A11A5678",
                    pillName:     "게보린정",
                    companyName:  "삼진제약",
                    pillImageUrl: nil
                ),
            ],
            page:          page,
            size:          size,
            totalElements: 2,
            totalPages:    1
        )
        return Just(stub)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
