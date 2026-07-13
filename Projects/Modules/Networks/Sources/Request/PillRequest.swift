//
//  PillRequest.swift
//  Networks
//
//  Created by 바견규 on 7/2/26.
//

import Foundation

// POST /api/v0/pill-attributes 요청 바디
public struct PillAttributeRequest: Encodable {
    // 원본 이미지 base64 (인프라 구축 전 임시 직접 전송. 이후 S3 key 방식으로 교체 예정)
    public let originalImage: String
    public let items: [PillAttributeItemRequest]

    public init(originalImage: String, items: [PillAttributeItemRequest]) {
        self.originalImage = originalImage
        self.items = items
    }
}

// 검출된 알약 1개 (polygon + 온디바이스 크롭)
public struct PillAttributeItemRequest: Encodable {
    // 세션 내 로컬 식별자. 응답의 pillId와 매핑 키로 사용
    public let pillId: String
    public let segmentation: [[Double]]  // [[x1,y1],[x2,y2],...] 폴리곤 좌표
    public let croppedImage: String      // 크롭 이미지 base64

    public init(pillId: String, segmentation: [[Double]], croppedImage: String) {
        self.pillId = pillId
        self.segmentation = segmentation
        self.croppedImage = croppedImage
    }
}

// POST /api/v0/pill-candidates 요청 바디 (색 필터는 필수·non-null, 나머지는 선택)
public struct PillCandidateRequest: Encodable {
    // 색 필터(required). 빈 배열이면 색 조건 제외. null 금지(OpenAPI required).
    public let colors: [PillColor]
    public let isTransparent: Bool?
    public let shape: PillShape?
    public let formulation: PillFormulation?
    public let front: PillFaceRequest?
    public let back: PillFaceRequest?
    // 다음 페이지 커서. 첫 페이지는 nil(생략). 직전 응답의 nextCursor.
    public let cursor: String?
    // 페이지 크기 (기본 20)
    public let size: Int

    public init(
        colors: [PillColor],
        isTransparent: Bool? = nil,
        shape: PillShape? = nil,
        formulation: PillFormulation? = nil,
        front: PillFaceRequest? = nil,
        back: PillFaceRequest? = nil,
        cursor: String? = nil,
        size: Int = 20
    ) {
        self.colors = colors
        self.isTransparent = isTransparent
        self.shape = shape
        self.formulation = formulation
        self.front = front
        self.back = back
        self.cursor = cursor
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
