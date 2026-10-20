//
//  PillLabelUseCase.swift
//  Domain
//

import Combine

/// 학습용 라벨 보내기 (NM-568 · spec label.md 「새 앱이 보내는 것」).
///
/// **베스트 에포트다.** 실패해도 식별 흐름을 막지 않고 사용자에게 알리지 않으며, 다시 시도하지 않는다 —
/// 그래서 결과를 돌려주지 않는다.
public protocol PillLabelUseCase {
    // 후보를 `선택` 하고 돌아올 때 그 알약 하나
    func sendLabel(imageId: String, pillIndex: Int, label: PillLabelModel)
    // `완료`(또는 종료 확인의 `종료`) 때 — 저장하지 않고 나가면 부르지 않는다
    func sendDeletedIndexes(imageId: String, deletedIndexes: [Int])
}

public final class DefaultPillLabelUseCase: PillLabelUseCase {
    private let repository: PillLabelRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    public init(repository: PillLabelRepositoryProtocol) {
        self.repository = repository
    }

    public func sendLabel(imageId: String, pillIndex: Int, label: PillLabelModel) {
        repository.saveLabel(imageId: imageId, pillIndex: pillIndex, label: label)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    public func sendDeletedIndexes(imageId: String, deletedIndexes: [Int]) {
        repository.saveDeletedIndexes(imageId: imageId, deletedIndexes: deletedIndexes)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
}
