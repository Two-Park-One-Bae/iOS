//
//  PillRepositoryInterface.swift
//  Domain
//
//  Created by 바견규 on 7/2/26.
//

import Combine
import Foundation

public protocol PillRepositoryProtocol {
    // 크롭 이미지 → 색·모양·제형 추출
    func fetchPillAttributes(
        originalImage: String,
        items: [(pillId: String, segmentation: [[Double]], croppedImage: String)]
    ) -> AnyPublisher<[PillAttributeModel], Error>

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
}
