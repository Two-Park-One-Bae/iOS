//
//  PillUseCase.swift
//  Domain
//
//  Created by 바견규 on 7/2/26.
//

import Combine
import Foundation

public protocol PillUseCase {
    // 촬영 → 속성 추출. 성공 시 pillAttributes 방출 (원본은 별도 S3 업로드, NM-348)
    func fetchPillAttributes(
        items: [(pillId: String, croppedImage: String)]
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

    // 원본 이미지 S3 업로드 (NM-348). 식별과 분리된 베스트 에포트 — 실패해도 무시, 방출 없음.
    func uploadOriginalImage(_ jpegData: Data)

    // 후보 선택 확정(pillCode) → 세부정보 조회 (NM-312)
    func fetchPillDetail(pillCode: String)

    // 잔여 식별 횟수 조회 (NM-331). 조회 전용 — 카운트가 늘지 않는다
    func fetchPillUsage()

    var pillAttributes: PassthroughSubject<[PillAttributeModel], Never> { get }
    var pillCandidates: PassthroughSubject<PillCandidatePageModel, Never> { get }
    var pillDetail:     PassthroughSubject<PillDetailModel, Never> { get }
    var errorMessage:   PassthroughSubject<String, Never> { get }

    // 서버가 준 최신 사용량. 식별 응답·조회 어느 쪽으로도 갱신된다
    var pillUsage:      CurrentValueSubject<PillUsageModel?, Never> { get }
    // 한도 도달 — UI는 이걸 받아 '한도 안내 팝업'을 띄운다 (429 또는 진입 게이트)
    var limitExceeded:  PassthroughSubject<PillUsageModel?, Never> { get }

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
    public let pillUsage      = CurrentValueSubject<PillUsageModel?, Never>(nil)
    public let limitExceeded  = PassthroughSubject<PillUsageModel?, Never>()
    public let pillDetailNotFound = PassthroughSubject<Void, Never>()
    public let pillDetailFailure  = PassthroughSubject<String, Never>()

    public init(repository: PillRepositoryProtocol) {
        self.repository = repository
    }

    public func fetchPillAttributes(
        items: [(pillId: String, croppedImage: String)]
    ) {
        repository.fetchPillAttributes(items: items)
            .catch { [weak self] error in
                // 429는 일반 오류(분석 실패 화면)가 아니라 한도 안내 팝업으로 분기한다
                if let limit = error as? PillLimitExceededError {
                    self?.pillUsage.send(limit.usage)
                    self?.limitExceeded.send(limit.usage)
                } else {
                    self?.errorMessage.send(error.localizedDescription)
                }
                return Empty<PillAttributeResultModel, Never>()
            }
            .sink { [weak self] result in
                // usage가 nil이면 서버가 아직 0.13.0 미적용 — 잔여를 '미확인'으로 두고 덮어쓰지 않는다
                if let usage = result.usage {
                    self?.pillUsage.send(usage)
                }
                self?.pillAttributes.send(result.items)
            }
            .store(in: &cancellables)
    }

    public func uploadOriginalImage(_ jpegData: Data) {
        // 베스트 에포트 — 성공·실패 모두 무시하고 방출하지 않는다. 식별 플로우와 완전 분리 (NM-348).
        repository.uploadOriginalImage(jpegData)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    public func fetchPillUsage() {
        repository.fetchPillUsage()
            .catch { _ in
                // 조회 실패는 식별을 막지 않는다 — 최종 판정은 식별 요청의 429다 (spec: 잔여 미확인 시 통과)
                Empty<PillUsageModel, Never>()
            }
            .sink { [weak self] usage in
                self?.pillUsage.send(usage)
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
