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
        let stub = items.enumerated().map { index, item -> PillAttributeModel in
            // 두 번째 알약은 색·모양·제형·각인 인식 실패 카드로 반환
            if index == 1 {
                return PillAttributeModel(
                    pillId:        item.pillId,
                    colors:        [],
                    isTransparent: false,
                    shape:         nil,
                    formulation:   nil,
                    front:         nil,
                    back:          nil,
                    error:         "RECOGNITION_FAILED"
                )
            }
            return PillAttributeModel(
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
        // 데모: 투명 알약으로 검색하면 "조건에 맞는 후보가 없어요" 빈 상태를 보여준다.
        // 토글을 끄면 다시 후보가 나타난다.
        if isTransparent == true {
            let empty = PillCandidatePageModel(
                candidates:    [],
                page:          page,
                size:          size,
                totalElements: 0,
                totalPages:    0
            )
            return Just(empty)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }

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
