//
//  PillEntity.swift
//  Domain
//
//  Created by 바견규 on 7/2/26.
//

import Foundation

/// 알약 1개의 속성 추출 결과 (서버 /api/v1 — NM-487 · NM-521).
///
/// 서버가 색 이름을 주지 않는다. 모델 출력은 **속성 토큰**으로 받아 후보 조회에 그대로 돌려주고(정렬용),
/// 화면에는 표시값(`colorHexes` · 대표 모양 · 대표 제형)만 쓴다.
/// 표시값은 검색 조건이 아니다 — 사용자가 직접 고른 값만 조건이 된다(spec candidate.md 「모델값과 사용자값」).
public struct PillAttributeModel: Equatable {
    public let pillId: String
    public let attributeToken: String?
    public let colorHexes: [String]
    public let shape: PillShapeModel?
    public let formulation: PillFormulationModel?
    /// `EXTRACTION_FAILED` 등. nil 이 아니면 나머지는 비어 있다 — 수정 화면은 모든 칸 `전체` 로 연다.
    public let error: String?

    public init(
        pillId: String,
        attributeToken: String?,
        colorHexes: [String],
        shape: PillShapeModel?,
        formulation: PillFormulationModel?,
        error: String?
    ) {
        self.pillId = pillId
        self.attributeToken = attributeToken
        self.colorHexes = colorHexes
        self.shape = shape
        self.formulation = formulation
        self.error = error
    }
}

/// 후보 카드의 면 정보(표시용). 구분선 `NONE` 은 nil 과 같이 '없음'으로 보인다.
public struct PillFaceModel: Equatable {
    public let imprint: String?
    public let dividingLine: DividingLineModel?
    public let hasMark: Bool
    /// 식약처 마크 코드(r0062 형식) — 표시용, 검색에 쓰지 않는다.
    public let markCode: String?

    public init(imprint: String?, dividingLine: DividingLineModel?, hasMark: Bool, markCode: String?) {
        self.imprint = imprint
        self.dividingLine = dividingLine
        self.hasMark = hasMark
        self.markCode = markCode
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
    /// 카탈로그 앞·뒷면 — 후보 카드 면 요약용 (NM-488).
    public let front: PillFaceModel?
    public let back: PillFaceModel?

    public init(
        pillCode: String,
        pillName: String?,
        companyName: String?,
        pillThumbnailUrl: String?,
        pillImageUrl: String? = nil,
        licenseStatus: LicenseStatus,
        front: PillFaceModel? = nil,
        back: PillFaceModel? = nil
    ) {
        self.pillCode = pillCode
        self.pillName = pillName
        self.companyName = companyName
        self.pillThumbnailUrl = pillThumbnailUrl
        self.pillImageUrl = pillImageUrl
        self.licenseStatus = licenseStatus
        self.front = front
        self.back = back
    }
}


/// 후보 조회 결과 — 서버가 정렬을 끝낸 pillCode 목록과 앞 20개 상세.
///
/// 순서는 `ids` 가 고정한다. 21번째부터는 `ids` 를 잘라 ID 로 조회한다(커서 없음).
public struct PillCandidateResultModel: Equatable {
    /// 정렬된 pillCode — 최대 200개.
    public let ids: [String]
    /// `ids` 앞 20개의 상세, 같은 순서.
    public let candidates: [PillCandidateModel]
    /// 하드 조건을 통과한 후보가 200개를 넘어 뒤가 잘렸는지 — 헤더 `200개+`.
    public let truncated: Bool

    public init(ids: [String], candidates: [PillCandidateModel], truncated: Bool) {
        self.ids = ids
        self.candidates = candidates
        self.truncated = truncated
    }
}

/// 후보 카드 일괄 조회 결과. `items` 는 순서가 없다 — 앱이 `ids` 순서대로 놓는다.
public struct PillCandidateItemsModel: Equatable {
    public let items: [PillCandidateModel]
    /// 요청했지만 그사이 사라진 pillCode — 목록에서 뺀다(로딩으로 남기지 않는다).
    public let missing: [String]

    public init(items: [PillCandidateModel], missing: [String]) {
        self.items = items
        self.missing = missing
    }
}

/// 서버가 속성 토큰을 해석하지 못함 (400 `INVALID_ATTRIBUTE_TOKEN`).
///
/// 앱은 토큰 없이 다시 조회한다 — 후보는 나오고 정렬만 덜 맞는다.
public struct PillInvalidAttributeTokenError: Error {
    public init() {}
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
