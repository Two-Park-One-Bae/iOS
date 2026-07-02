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
