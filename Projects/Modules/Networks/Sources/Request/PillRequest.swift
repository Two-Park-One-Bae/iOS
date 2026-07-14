//
//  PillRequest.swift
//  Networks
//
//  Created by 바견규 on 7/2/26.
//

import Foundation

// OpenAPI `Image` 스키마 — 이미지는 문자열이 아니라 { mimeType, data } 객체.
public struct PillImageRequest: Encodable {
    public let mimeType: String   // 예: image/jpeg, image/png
    public let data: String       // base64 인코딩 바이트(data URI 프리픽스 없이 순수 base64)

    public init(mimeType: String, data: String) {
        self.mimeType = mimeType
        self.data = data
    }
}

// OpenAPI `Segmentation` 스키마 — 폴리곤은 배열이 아니라 { type, points } 객체.
public struct SegmentationRequest: Encodable {
    public let type: String        // BBOX | POLYGON
    public let points: [[Double]]  // 원본 좌표. POLYGON=꼭짓점, BBOX=[[x,y,w,h]]

    public init(type: String, points: [[Double]]) {
        self.type = type
        self.points = points
    }
}

// POST /api/v0/pill-attributes 요청 바디
public struct PillAttributeRequest: Encodable {
    // 원본 이미지(인프라 구축 전 임시 직접 전송. 이후 S3 key 방식으로 교체 예정)
    public let originalImage: PillImageRequest
    public let items: [PillAttributeItemRequest]

    public init(originalImage: PillImageRequest, items: [PillAttributeItemRequest]) {
        self.originalImage = originalImage
        self.items = items
    }
}

// 검출된 알약 1개 (polygon + 온디바이스 크롭)
public struct PillAttributeItemRequest: Encodable {
    // 세션 내 로컬 식별자. 응답의 pillId와 매핑 키로 사용
    public let pillId: String
    public let segmentation: SegmentationRequest  // 폴리곤 객체
    public let croppedImage: PillImageRequest      // 크롭 이미지 객체

    public init(pillId: String, segmentation: SegmentationRequest, croppedImage: PillImageRequest) {
        self.pillId = pillId
        self.segmentation = segmentation
        self.croppedImage = croppedImage
    }
}

// POST /api/v0/pill-candidates 요청 바디 (전부 선택, 부분 입력 허용)
public struct PillCandidateRequest: Encodable {
    public let colors: [PillColor]?
    public let isTransparent: Bool?
    public let shape: PillShape?
    public let formulation: PillFormulation?
    public let front: PillFaceRequest?
    public let back: PillFaceRequest?
    // 0-base 페이지 번호
    public let page: Int
    // 페이지 크기 (기본 20)
    public let size: Int

    public init(
        colors: [PillColor]? = nil,
        isTransparent: Bool? = nil,
        shape: PillShape? = nil,
        formulation: PillFormulation? = nil,
        front: PillFaceRequest? = nil,
        back: PillFaceRequest? = nil,
        page: Int = 0,
        size: Int = 20
    ) {
        self.colors = colors
        self.isTransparent = isTransparent
        self.shape = shape
        self.formulation = formulation
        self.front = front
        self.back = back
        self.page = page
        self.size = size
    }
}

// 알약 한 면 (각인 수동 입력)
public struct PillFaceRequest: Encodable {
    public let imprint: String?
    public let dividingLine: DividingLine?
    public let hasMark: Bool?

    public init(imprint: String? = nil, dividingLine: DividingLine? = nil, hasMark: Bool? = nil) {
        self.imprint = imprint
        self.dividingLine = dividingLine
        self.hasMark = hasMark
    }
}
