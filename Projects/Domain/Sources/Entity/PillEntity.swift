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

// 허가상태(NM-337). REVOKED = 허가 취소·취하 통합 — '허가 종료' 배지·후순위·세부정보 조회 생략 기준.
public enum LicenseStatus: Equatable {
    case normal
    case revoked
}

// 후보 알약 1개
public struct PillCandidateModel: Equatable {
    public let pillCode: String
    public let pillName: String?
    public let companyName: String?
    public let pillThumbnailUrl: String?   // 목록 대조용 썸네일 (NM-347). 원본은 세부정보에서 조회.
    public let pillImageUrl: String?       // 낱알 원본 이미지 (썸네일 탭 시 원본 대조 뷰어용, NM-356). 없으면 폴백.
    public let licenseStatus: LicenseStatus

    public init(
        pillCode: String,
        pillName: String?,
        companyName: String?,
        pillThumbnailUrl: String?,
        pillImageUrl: String? = nil,
        licenseStatus: LicenseStatus
    ) {
        self.pillCode = pillCode
        self.pillName = pillName
        self.companyName = companyName
        self.pillThumbnailUrl = pillThumbnailUrl
        self.pillImageUrl = pillImageUrl
        self.licenseStatus = licenseStatus
    }
}

// 후보 목록 + 커서 페이지네이션
public struct PillCandidatePageModel: Equatable {
    public let candidates: [PillCandidateModel]
    public let nextCursor: String?   // 다음 페이지 커서. nil이면 마지막 페이지
    public let hasNext: Bool

    public init(
        candidates: [PillCandidateModel],
        nextCursor: String?,
        hasNext: Bool
    ) {
        self.candidates = candidates
        self.nextCursor = nextCursor
        self.hasNext = hasNext
    }
}

// MARK: - Pill Detail (NM-312)

// 알약 세부정보 (성분·성상·허가문서). 허가문서는 구조화된 블록 목록.
public struct PillDetailModel: Equatable {
    public let pillCode: String
    public let name: String
    public let companyName: String
    public let pillImageUrl: String?   // 낱알 원본 이미지 (세부정보 실물 대조, NM-347)
    public let classification: PillClassificationModel
    public let appearance: String?
    public let ingredients: [IngredientModel]
    public let storageMethod: String?
    public let validTerm: String?
    public let packUnit: String?
    public let documents: [LicenseDocModel]

    public init(
        pillCode: String,
        name: String,
        companyName: String,
        pillImageUrl: String?,
        classification: PillClassificationModel,
        appearance: String?,
        ingredients: [IngredientModel],
        storageMethod: String?,
        validTerm: String?,
        packUnit: String?,
        documents: [LicenseDocModel]
    ) {
        self.pillCode = pillCode
        self.name = name
        self.companyName = companyName
        self.pillImageUrl = pillImageUrl
        self.classification = classification
        self.appearance = appearance
        self.ingredients = ingredients
        self.storageMethod = storageMethod
        self.validTerm = validTerm
        self.packUnit = packUnit
        self.documents = documents
    }
}

public struct IngredientModel: Equatable {
    public let name: String
    public let amount: String
    public let unit: String

    public init(name: String, amount: String, unit: String) {
        self.name = name
        self.amount = amount
        self.unit = unit
    }
}

public struct LicenseDocModel: Equatable {
    public let type: LicenseDocTypeModel
    public let blocks: [BlockModel]

    public init(type: LicenseDocTypeModel, blocks: [BlockModel]) {
        self.type = type
        self.blocks = blocks
    }
}

// 문서 블록. 모르는 블록 타입은 매핑 단계에서 제외되어 여기엔 알려진 타입만 존재.
public enum BlockModel: Equatable {
    case heading(content: [SpanModel])
    case paragraph(content: [SpanModel])
    case table(caption: [SpanModel]?, rows: [TableRowModel])
    case image(src: String)
}

public struct TableRowModel: Equatable {
    public let cells: [TableCellModel]

    public init(cells: [TableCellModel]) {
        self.cells = cells
    }
}

public struct TableCellModel: Equatable {
    public let content: [SpanModel]
    public let colspan: Int
    public let rowspan: Int
    public let header: Bool

    public init(content: [SpanModel], colspan: Int, rowspan: Int, header: Bool) {
        self.content = content
        self.colspan = colspan
        self.rowspan = rowspan
        self.header = header
    }
}

// 텍스트 조각. style이 nil이면 일반 텍스트.
public struct SpanModel: Equatable {
    public let text: String
    public let style: SpanStyleModel?

    public init(text: String, style: SpanStyleModel?) {
        self.text = text
        self.style = style
    }
}

// MARK: - Enums

public enum PillClassificationModel: String, Equatable {
    case etc, otc, unknown
}

public enum LicenseDocTypeModel: String, Equatable {
    case effect, dosage, caution, unknown
}

public enum SpanStyleModel: String, Equatable {
    case sup, sub
}

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
