//
//  PillUseCase.swift
//  Domain
//
//  Created by 바견규 on 7/2/26.
//

import Combine
import Foundation

public protocol PillUseCase {
    // 촬영 → 속성 추출. 성공 시 pillAttributes 방출
    func fetchPillAttributes(
        originalImage: String,
        items: [(pillId: String, segmentation: [[Double]], croppedImage: String)]
    )

    // 속성 수정 → 후보 조회. 실시간 재호출용
    func fetchPillCandidates(
        colors: [PillColorModel]?,
        isTransparent: Bool?,
        shape: PillShapeModel?,
        formulation: PillFormulationModel?,
        front: PillFaceModel?,
        back: PillFaceModel?,
        cursor: String?,
        size: Int
    )

    var pillAttributes: PassthroughSubject<[PillAttributeModel], Never> { get }
    var pillCandidates: PassthroughSubject<PillCandidatePageModel, Never> { get }
    var errorMessage:   PassthroughSubject<String, Never> { get }
}

public final class DefaultPillUseCase: PillUseCase {
    private let repository: PillRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    public let pillAttributes = PassthroughSubject<[PillAttributeModel], Never>()
    public let pillCandidates = PassthroughSubject<PillCandidatePageModel, Never>()
    public let errorMessage   = PassthroughSubject<String, Never>()

    public init(repository: PillRepositoryProtocol) {
        self.repository = repository
    }

    public func fetchPillAttributes(
        originalImage: String,
        items: [(pillId: String, segmentation: [[Double]], croppedImage: String)]
    ) {
        repository.fetchPillAttributes(originalImage: originalImage, items: items)
            .catch { [weak self] error in
                self?.errorMessage.send(error.localizedDescription)
                return Empty<[PillAttributeModel], Never>()
            }
            .sink { [weak self] attributes in
                self?.pillAttributes.send(attributes)
            }
            .store(in: &cancellables)
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
    ) {
        repository.fetchPillCandidates(
            colors: colors,
            isTransparent: isTransparent,
            shape: shape,
            formulation: formulation,
            front: front,
            back: back,
            cursor: cursor,
            size: size
        )
        .catch { [weak self] error in
            self?.errorMessage.send(error.localizedDescription)
            return Empty<PillCandidatePageModel, Never>()
        }
        .sink { [weak self] page in
            self?.pillCandidates.send(page)
        }
        .store(in: &cancellables)
    }
}
