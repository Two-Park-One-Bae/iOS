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

// POST /api/v1/pill-attributes 요청 바디 — 크롭만 전달한다.
// 원본은 /api/v0/pill-images/upload-url로 S3에 직접 업로드하며 식별 요청과 분리된다 (NM-348).
public struct PillAttributeRequest: Encodable {
    public let items: [PillAttributeItemRequest]

    public init(items: [PillAttributeItemRequest]) {
        self.items = items
    }
}

// 검출된 알약 1개 (온디바이스 크롭)
public struct PillAttributeItemRequest: Encodable {
    // 세션 내 로컬 식별자. 응답의 pillId와 매핑 키로 사용
    public let pillId: String
    public let croppedImage: PillImageRequest      // 크롭 이미지 객체

    public init(pillId: String, croppedImage: PillImageRequest) {
        self.pillId = pillId
        self.croppedImage = croppedImage
    }
}

// POST /api/v1/pill-candidates 요청 바디 (NM-488). nil 은 키째 빠진다 = 조건 제외.
public struct PillCandidateRequest: Encodable {
    // 속성 추출 응답의 attributeToken 그대로 — 무엇을 고쳤든 항상. 수동 추가·추출 실패는 nil.
    public let attributeToken: String?
    // 사용자가 고른 색만(점수). 빈 배열이면 사용자색 항 없음.
    public let colors: [PillColor]
    // 사용자가 고른 모양·제형만 — 하드 필터. 대표값을 그대로 보내지 않는다.
    public let shape: PillShape?
    public let formulation: PillFormulation?
    public let front: PillFaceRequest?
    public let back: PillFaceRequest?

    public init(
        attributeToken: String?,
        colors: [PillColor],
        shape: PillShape?,
        formulation: PillFormulation?,
        front: PillFaceRequest?,
        back: PillFaceRequest?
    ) {
        self.attributeToken = attributeToken
        self.colors = colors
        self.shape = shape
        self.formulation = formulation
        self.front = front
        self.back = back
    }
}

// v1 면 조건. imprint 가 있으면 imprintSource 필수(없으면 400).
public struct PillFaceRequest: Encodable {
    // "" = 각인 없는 알약만(사용자값에서만)
    public let imprint: String?
    // "MODEL" | "USER"
    public let imprintSource: String?
    // NONE = 구분선 없는 알약
    public let dividingLine: DividingLine?
    public let hasMark: Bool?
    // base64 · fp16 LE · 8×768 row-major (12,288 B → 16,384자). 정렬에만 쓰인다.
    public let markEmbedding: String?

    public init(
        imprint: String?,
        imprintSource: String?,
        dividingLine: DividingLine?,
        hasMark: Bool?,
        markEmbedding: String?
    ) {
        self.imprint = imprint
        self.imprintSource = imprintSource
        self.dividingLine = dividingLine
        self.hasMark = hasMark
        self.markEmbedding = markEmbedding
    }
}
