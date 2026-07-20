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

    // 후보 선택 확정(pillCode) → 세부정보 조회 (NM-312)
    func fetchPillDetail(pillCode: String)

    var pillAttributes: PassthroughSubject<[PillAttributeModel], Never> { get }
    var pillCandidates: PassthroughSubject<PillCandidatePageModel, Never> { get }
    var pillDetail:     PassthroughSubject<PillDetailModel, Never> { get }
    var errorMessage:   PassthroughSubject<String, Never> { get }

    // 세부정보 조회 전용 채널 — 공유 errorMessage로 흘리면 다른 화면(분석 등)까지 새므로 분리 (NM-309)
    var pillDetailNotFound: PassthroughSubject<Void, Never> { get }
    var pillDetailFailure:  PassthroughSubject<String, Never> { get }
}

public final class DefaultPillUseCase: PillUseCase {
    private let repository: PillRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    // 후보 조회는 실시간 재호출되므로 전용 cancellable 로 관리 —
    // 새 호출 시 이전 in-flight 요청을 취소해 동시 요청 누적/응답 뒤섞임을 막는다.
    private var candidatesCancellable: AnyCancellable?

    public let pillAttributes = PassthroughSubject<[PillAttributeModel], Never>()
    public let pillCandidates = PassthroughSubject<PillCandidatePageModel, Never>()
    public let pillDetail     = PassthroughSubject<PillDetailModel, Never>()
    public let errorMessage   = PassthroughSubject<String, Never>()
    public let pillDetailNotFound = PassthroughSubject<Void, Never>()
    public let pillDetailFailure  = PassthroughSubject<String, Never>()

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
        // 이전 요청을 취소하고 최신 요청만 유지(switch-to-latest 효과).
        candidatesCancellable = repository.fetchPillCandidates(
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
    }

    public func fetchPillDetail(pillCode: String) {
        repository.fetchPillDetail(pillCode: pillCode)
            .catch { [weak self] error in
                // 세부정보 조회 오류는 전용 채널로만 보낸다 — 공유 errorMessage에 흘리면
                // 분석 화면 등 다른 구독자에게까지 새어 '분석 실패' 화면이 겹쳐 뜬다.
                if error is PillDetailNotFoundError {
                    self?.pillDetailNotFound.send(())      // 404 → '세부정보 없음' (오류 아님)
                } else {
                    self?.pillDetailFailure.send(error.localizedDescription)
                }
                return Empty<PillDetailModel, Never>()
            }
            .sink { [weak self] detail in
                self?.pillDetail.send(detail)
            }
            .store(in: &cancellables)
    }
}
