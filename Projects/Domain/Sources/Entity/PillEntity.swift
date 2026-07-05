//
//  PillEntity.swift
//  Domain
//
//  Created by 바견규 on 7/2/26.
//

import Foundation

// 알약 1개의 색·모양·제형 분석 결과 (비즈니스 모델)
public struct PillAttributeModel: Equatable {
    public let pillId: String
    public let colors: [PillColorModel]
    public let isTransparent: Bool
    public let shape: PillShapeModel?
    public let formulation: PillFormulationModel?
    public let front: PillFaceModel?
    public let back: PillFaceModel?
    // 개별 알약 추출 실패 시 에러 코드. 성공 시 nil
    public let error: String?

    public init(
        pillId: String,
        colors: [PillColorModel],
        isTransparent: Bool,
        shape: PillShapeModel?,
        formulation: PillFormulationModel?,
        front: PillFaceModel?,
        back: PillFaceModel?,
        error: String?
    ) {
        self.pillId = pillId
        self.colors = colors
        self.isTransparent = isTransparent
        self.shape = shape
        self.formulation = formulation
        self.front = front
        self.back = back
        self.error = error
    }
}

public struct PillFaceModel: Equatable {
    public let imprint: String?
    public let dividingLine: DividingLineModel?
    public let hasMark: Bool?

    public init(imprint: String?, dividingLine: DividingLineModel?, hasMark: Bool?) {
        self.imprint = imprint
        self.dividingLine = dividingLine
        self.hasMark = hasMark
    }
}

// 후보 알약 1개
public struct PillCandidateModel: Equatable {
    public let pillCode: String
    public let pillName: String?
    public let companyName: String?
    public let pillImageUrl: String?

    public init(
        pillCode: String,
        pillName: String?,
        companyName: String?,
        pillImageUrl: String?
    ) {
        self.pillCode = pillCode
        self.pillName = pillName
        self.companyName = companyName
        self.pillImageUrl = pillImageUrl
    }
}

// 후보 목록 + 페이지네이션
public struct PillCandidatePageModel: Equatable {
    public let candidates: [PillCandidateModel]
    public let page: Int
    public let size: Int
    public let totalElements: Int
    public let totalPages: Int

    public init(
        candidates: [PillCandidateModel],
        page: Int,
        size: Int,
        totalElements: Int,
        totalPages: Int
    ) {
        self.candidates = candidates
        self.page = page
        self.size = size
        self.totalElements = totalElements
        self.totalPages = totalPages
    }
}

// MARK: - Enums

public enum PillColorModel: String, Equatable {
    case white, yellow, orange, pink, red, brown
    case lightGreen, green, teal, blue, navy, magenta, purple
    case gray, black, colorless, unknown
}

public enum PillShapeModel: String, Equatable {
    case round, oval, oblong, semicircle, triangle
    case square, diamond, pentagon, hexagon, octagon
    case other, unknown
}

public enum PillFormulationModel: String, Equatable {
    case tablet, hardCapsule, softCapsule, other, unknown
}

public enum DividingLineModel: String, Equatable {
    case plus, minus, unknown
}
