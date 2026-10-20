//
//  PillRequest.swift
//  Networks
//
//  Created by 바견규 on 7/2/26.
//

import Foundation

// OpenAPI `Image` 스키마 — 이미지는 문자열이 아니라 { mimeType, data } 객체.
public struct PillImageRequest: Encodable {
    public let mimeType: String   // spec 은 image/png 만 허용 — 크롭은 마스크를 알파에 담은 PNG
    public let data: String       // base64 인코딩 바이트(data URI 프리픽스 없이 순수 base64)

    public init(mimeType: String, data: String) {
        self.mimeType = mimeType
        self.data = data
    }
}

// POST /api/v1/pill-attributes 요청 바디 — 크롭만 전달한다.
// 원본은 /api/v0/pill-images/upload-url로 S3에 직접 업로드하며 식별과 분리된다 (NM-348).
// imageId 부터는 학습용 라벨 값(NM-568) — 보내면 서버가 응답 뒤 크롭 · 알약 행 · 알약 위치 행을 저장한다.
// nil 이면 키째 빠져 지금과 같다(내부 빌드는 보내지 않는다).
public struct PillAttributeRequest: Encodable {
    public let items: [PillAttributeItemRequest]
    // 앱이 만든 UUID v7 — upload-url 에 보낸 값과 같다
    public let imageId: String?
    // 업로드한 원본 픽셀 크기
    public let imageWidth: Int?
    public let imageHeight: Int?
    // 알약 찾기 모델 버전(ML 레포 모델 폴더 이름)
    public let segModel: String?

    public init(
        items: [PillAttributeItemRequest],
        imageId: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        segModel: String? = nil
    ) {
        self.items = items
        self.imageId = imageId
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.segModel = segModel
    }
}

// 검출된 알약 1개 (온디바이스 크롭)
public struct PillAttributeItemRequest: Encodable {
    // 세션 내 로컬 식별자. 응답의 pillId와 매핑 키로 사용. 라벨을 보낼 때는 0~99 정수 문자열(= pillIndex)
    public let pillId: String
    public let croppedImage: PillImageRequest      // 크롭 이미지 객체
    // 라벨용(NM-568) — 크롭 위치 [x, y, 너비, 높이], 업로드한 원본 픽셀 기준. 너비 · 높이 = 크롭 크기
    public let box: [Int]?
    // 라벨용(NM-568) — 알약 찾기 점수(0~1)
    public let score: Double?

    public init(pillId: String, croppedImage: PillImageRequest, box: [Int]? = nil, score: Double? = nil) {
        self.pillId = pillId
        self.croppedImage = croppedImage
        self.box = box
        self.score = score
    }
}

// POST /api/v1/pill-candidates 요청 바디 (NM-488). nil 은 키째 빠진다 = 조건 제외.
public struct PillCandidateRequest: Encodable {
    // 속성 추출 응답의 attributeToken 그대로 — 무엇을 고쳤든 항상. 수동 추가·추출 실패는 nil.
    public let attributeToken: String?
    // 면 markEmbedding 을 뽑은 마크 모델 버전(ML 레포 모델 폴더 이름). 어느 면이든 임베딩이 있으면 필수 — 없으면 400 (NM-533)
    public let markEmbeddingModel: String?
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
        back: PillFaceRequest?,
        markEmbeddingModel: String? = nil
    ) {
        self.attributeToken = attributeToken
        self.markEmbeddingModel = markEmbeddingModel
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

/// `PUT /api/v0/pill-histories/{historyId}` 본문 — 확정한 품목, 화면 순서 그대로 (NM-552).
public struct PillHistorySaveRequest: Encodable {
    public let pillCodes: [String]

    public init(pillCodes: [String]) {
        self.pillCodes = pillCodes
    }
}

/// `POST /api/v0/pill-images/upload-url` 본문 — 앱이 만든 UUID v7 을 원본 키의 uuid 로 쓴다 (NM-568).
public struct PillImageUploadURLRequest: Encodable {
    public let imageId: String

    public init(imageId: String) {
        self.imageId = imageId
    }
}

/// `PUT /api/v0/pill-images/{imageId}/labels/{pillIndex}` 본문 — 「선택」한 알약 하나의 라벨 (NM-568).
/// model · userInput 은 후보 조회 요청 본문 그대로다.
public struct PillLabelRequest: Encodable {
    public let pillCode: String
    // 수동 추가 알약 — model 이 없다
    public let manual: Bool
    // 첫 후보 조회 요청. 수동 추가는 nil(보내면 400)
    public let model: PillCandidateRequest?
    // 마지막 후보 조회 요청
    public let userInput: PillCandidateRequest

    public init(pillCode: String, manual: Bool, model: PillCandidateRequest?, userInput: PillCandidateRequest) {
        self.pillCode = pillCode
        self.manual = manual
        self.model = model
        self.userInput = userInput
    }
}

/// `PATCH /api/v0/pill-images/{imageId}/segmentation` 본문 — `완료` 때 사용자가 지운 알약 번호 (NM-568).
public struct PillSegmentationSaveRequest: Encodable {
    public let deletedIndexes: [Int]

    public init(deletedIndexes: [Int]) {
        self.deletedIndexes = deletedIndexes
    }
}
