//
//  PillLabelRepositoryInterface.swift
//  Domain
//

import Combine

/// 학습용 라벨 (NM-568). 회원과 잇지 않는 익명 데이터다 — 키는 사진 id(`imageId`)와 알약 번호뿐이다.
public protocol PillLabelRepositoryProtocol {
    // 「선택」한 알약 하나의 라벨. 다시 보내면 덮어쓴다
    func saveLabel(imageId: String, pillIndex: Int, label: PillLabelModel) -> AnyPublisher<Void, Error>
    // `완료` 때 사용자가 지운 알약 번호(모델 알약만). 지운 게 없으면 빈 배열
    func saveDeletedIndexes(imageId: String, deletedIndexes: [Int]) -> AnyPublisher<Void, Error>
}
