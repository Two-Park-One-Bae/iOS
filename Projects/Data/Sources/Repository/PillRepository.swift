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
        items: [(pillId: String, croppedImage: String)]
    ) -> AnyPublisher<PillAttributeResultModel, Error> {
        // OpenAPI 스키마에 맞춰 이미지를 {mimeType, data}로 감싼다. 크롭 썸네일은 png(ViewModel 기준).
        // 원본은 이 요청에 싣지 않는다 — pill-images/upload-url로 S3 직접 업로드(NM-348).
        let requestItems = items.map {
            PillAttributeItemRequest(
                pillId: $0.pillId,
                croppedImage: PillImageRequest(mimeType: "image/png", data: $0.croppedImage)
            )
        }
        let request = PillAttributeRequest(items: requestItems)

        return service.fetchPillAttributes(request: request)
            .map { $0.toDomain() }
            .mapError { Self.mapLimitExceeded($0) }
            .eraseToAnyPublisher()
    }

    public func uploadOriginalImage(_ jpegData: Data) -> AnyPublisher<Void, Error> {
        // presigned URL 발급 → 그 URL로 S3에 원본 JPEG을 직접 PUT. (NM-348)
        // API 베이스가 아닌 임의 presigned URL이라 Moya가 아닌 URLSession으로 올린다(App Check 불필요).
        service.issuePillImageUploadURL()
            .flatMap { issued -> AnyPublisher<Void, Error> in
                guard let url = URL(string: issued.uploadUrl) else {
                    return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
                }
                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                request.httpBody = jpegData
                return URLSession.shared.dataTaskPublisher(for: request)
                    .tryMap { output in
                        guard let http = output.response as? HTTPURLResponse,
                              (200..<300).contains(http.statusCode) else {
                            throw URLError(.badServerResponse)
                        }
                        return ()
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    public func fetchPillUsage() -> AnyPublisher<PillUsageModel, Error> {
        service.fetchPillUsage()
            .map { $0.toDomain() }
            .eraseToAnyPublisher()
    }

    /// 429 `LIMIT_EXCEEDED`만 UI가 '한도 안내 팝업'으로 분기할 수 있도록 도메인 에러로 올린다.
    /// 나머지는 그대로 통과 — 일반 오류 처리 경로를 바꾸지 않는다.
    private static func mapLimitExceeded(_ error: Error) -> Error {
        guard case APIError.network(let statusCode, let problem) = error, statusCode == 429 else {
            return error
        }

        // usage는 RFC 9457 확장 멤버라 NetworkError에 없다 — 보존해둔 원문에서 꺼낸다.
        let usage = problem.rawBody
            .flatMap { try? JSONDecoder().decode(PillLimitExceededEntity.self, from: $0) }
            .map { $0.usage.toDomain() }

        return PillLimitExceededError(usage: usage)
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
    ) -> AnyPublisher<PillCandidatePageModel, Error> {
        // Domain 모델 → Network Request 모델 변환. colors는 required·non-null(nil이면 빈 배열).
        let request = PillCandidateRequest(
            colors: colors?.compactMap { $0.toNetwork() } ?? [],
            isTransparent: isTransparent,
            shape: shape?.toNetwork(),
            formulation: formulation?.toNetwork(),
            front: front?.toNetwork(),
            back: back?.toNetwork(),
            cursor: cursor,
            size: size
        )

        return service.fetchPillCandidates(request: request)
            .map { $0.toDomain() }
            .eraseToAnyPublisher()
    }

    public func fetchPillDetail(pillCode: String) -> AnyPublisher<PillDetailModel, Error> {
        service.fetchPillDetail(pillCode: pillCode)
            .map { $0.toDomain() }
            .mapError { Self.mapDetailNotFound($0) }
            .eraseToAnyPublisher()
    }

    /// 404 `PILL_DETAIL_NOT_FOUND` 만 '세부정보 없음' 타입 에러로 올린다 (NM-309).
    /// 나머지는 그대로 통과.
    private static func mapDetailNotFound(_ error: Error) -> Error {
        guard case APIError.network(let statusCode, let problem) = error else { return error }
        if statusCode == 404 || problem.code == "PILL_DETAIL_NOT_FOUND" {
            return PillDetailNotFoundError()
        }
        return error
    }
}
