//
//  PillConditions.swift
//  Domain
//
//  수정 화면의 알약 조건 상태 (NM-513) — 후보 조회 요청(NM-514)의 원천.
//
//  규칙의 정본: spec api/domains/candidate.md 「모델값과 사용자값」 · 「마크 유무」,
//  feature/pill-recognition/README.md 「수정·후보 선택」, DESIGN.pen NM-490 ③.
//

import Foundation

// MARK: - 칸 색

/// 칸이 **확실한 값**인지. 필터인지 점수인지가 아니다 — 계약에서 필터·점수가 바뀌어도 화면 규칙은 그대로다.
public enum ConditionTone: Equatable {
    /// 회색 — `전체`(조건 없음), 모델이 추정한 색·모양·제형.
    case estimate
    /// 호박색 — 모델이 확신한 각인·마크 유무, 사용자가 정한 모든 값.
    case confirmed
}

// MARK: - 모델 출력 (되돌리기 원본)

/// 알약 한 장에서 모델이 낸 값. 조건이 바뀌어도 그대로 두고, 되돌리면 여기로 돌아간다.
///
/// 뒷면은 사진이 없어 모델 출력이 없다 — 앞면 = 처음 찍은 사진의 면(spec PillCandidateRequest.front).
public struct PillModelOutput: Equatable {
    /// 서버 속성 토큰. 수동 추가 · 추출 실패면 nil.
    public let attributeToken: String?
    public let colorHexes: [String]
    public let shape: PillShapeModel?
    public let formulation: PillFormulationModel?
    /// 온디바이스 각인 모델의 **확신 글자**(NM-459). 확신 글자가 없으면 nil — 모델은 `""` 을 내지 않는다.
    public let frontImprint: String?
    /// 온디바이스 마크 모델의 유무 점수 `1 − P(없음)`(NM-512).
    public let frontMarkScore: Float?
    /// 앞면 임베딩 8×768(온디바이스 마크 모델이 낸다) — 걸러진 후보를 **최종 재정렬**하는 데만 쓴다.
    /// 마크 조건과 무관하게 항상 보낸다. 요청 필드 이름은 spec 의 `markEmbedding`, 전송 형식(base64 · fp16)과
    /// 함께 후보 조회 요청을 만들 때 맞춘다(NM-514).
    public let frontEmbedding: [Float]?

    public init(
        attributeToken: String? = nil,
        colorHexes: [String] = [],
        shape: PillShapeModel? = nil,
        formulation: PillFormulationModel? = nil,
        frontImprint: String? = nil,
        frontMarkScore: Float? = nil,
        frontEmbedding: [Float]? = nil
    ) {
        self.attributeToken = attributeToken
        self.colorHexes = colorHexes
        self.shape = shape
        self.formulation = formulation
        self.frontImprint = frontImprint.flatMap { $0.isEmpty ? nil : $0 }
        self.frontMarkScore = frontMarkScore
        self.frontEmbedding = frontEmbedding
    }

    /// 수동 추가(NM-187) — 사진이 없어 모델 출력이 없다.
    public static let empty = PillModelOutput()

    /// 서버 추출 결과 + 기기 모델 결과. 추출 실패(`error`)면 서버 쪽 값은 버린다 — 수정 화면은 모든 칸 `전체`.
    public init(
        attribute: PillAttributeModel,
        frontImprint: String? = nil,
        frontMarkScore: Float? = nil,
        frontEmbedding: [Float]? = nil
    ) {
        let ok = attribute.error == nil
        self.init(
            attributeToken: ok ? attribute.attributeToken : nil,
            colorHexes: ok ? attribute.colorHexes : [],
            shape: ok ? attribute.shape : nil,
            formulation: ok ? attribute.formulation : nil,
            frontImprint: frontImprint,
            frontMarkScore: frontMarkScore,
            frontEmbedding: frontEmbedding
        )
    }
}

/// 마크 유무 점수를 조건으로 접는 규칙 — **계약이 소유한다**(두 앱이 다르게 접으면 같은 알약에 다른 후보가 나온다).
///
/// 임계는 **같은 면의 각인 유무로 나눈다**(NM-527) — 각인 모델값(확신 글자)이 있으면 0.80, 없으면 0.60.
/// 각인이 있는 면은 각인만으로 후보가 좁혀지므로 마크를 확실할 때만 건다(놓친 `true` 하나가 정답을 떨어뜨린다).
/// 각인이 없으면 마크가 남은 단서라 더 낮은 점수에서도 건다. 현 마크 모델(convnext-species) 기준 —
/// 모델을 바꾸면 spec 과 함께 고친다.
public enum PillMarkRule {
    public static let presenceThresholdWithImprint: Float = 0.80
    public static let presenceThresholdWithoutImprint: Float = 0.60

    /// 모델 점수가 `있음` 인가. `imprint` 는 같은 면의 각인 모델값 — nil(보류·판독 실패)이면 각인 없음으로 본다.
    public static func isPresent(score: Float?, imprint: String?) -> Bool {
        guard let score else { return false }
        let hasImprint = !(imprint ?? "").isEmpty
        return score >= (hasImprint ? presenceThresholdWithImprint : presenceThresholdWithoutImprint)
    }
}

// MARK: - 외형 (색 · 모양 · 제형)

/// 색 · 모양 · 제형 한 칸. `전체` 면 모델값을 보여 주되(회색) 조건이 아니다 — 정렬에만 쓰인다.
public enum AppearanceCondition<Value: Equatable>: Equatable {
    /// `전체` — 조건 없음.
    case all
    /// 사용자가 메뉴에서 고른 값. 모델값과 같아도 사용자값이다.
    case user(Value)

    public var tone: ConditionTone {
        switch self {
        case .all:  return .estimate
        case .user: return .confirmed
        }
    }

    public var userValue: Value? {
        if case .user(let value) = self { return value }
        return nil
    }
}

// MARK: - 면 (각인 · 구분선 · 마크) — 3단

/// 값의 출처. 각인은 요청에 그대로 실린다(`imprintSource`) — 서버가 이걸 보고 매칭 엄격도를 정한다
/// (모델값은 확신 글자만이라 사이 글자가 빠져 있을 수 있다). 마크는 칸 표시에만 쓴다.
public enum ValueSource: Equatable {
    case model
    case user
}

/// 각인 한 칸 — `전체 · 없음 · 값`.
public enum ImprintCondition: Equatable {
    case all
    /// 각인 없는 알약만. **사용자만** 고른다(입력칸을 비우고 확인).
    case none
    case value(String, source: ValueSource)

    public var tone: ConditionTone {
        self == .all ? .estimate : .confirmed
    }
}

/// 구분선 한 칸 — `전체 · 없음 · (+)형 · (−)형`. 모델이 없어 모든 값이 사용자값이다.
public enum DividingLineCondition: Equatable {
    case all
    case none
    case value(DividingLineModel)

    public var tone: ConditionTone {
        self == .all ? .estimate : .confirmed
    }
}

/// 마크 유무 한 칸 — `전체 · 없음 · 있음`.
public enum MarkCondition: Equatable {
    case all
    /// 마크 없는 알약만. **사용자만** 고른다 — 모델이 마크를 놓치고 `없음` 을 보내면 정답이 통째로 빠진다.
    case none
    case present(source: ValueSource)

    public var tone: ConditionTone {
        self == .all ? .estimate : .confirmed
    }
}

public struct FaceConditions: Equatable {
    public var imprint: ImprintCondition
    public var dividingLine: DividingLineCondition
    public var mark: MarkCondition

    public init(imprint: ImprintCondition = .all, dividingLine: DividingLineCondition = .all, mark: MarkCondition = .all) {
        self.imprint = imprint
        self.dividingLine = dividingLine
        self.mark = mark
    }
}

public enum PillFace: Equatable {
    case front
    case back
}

// MARK: - 알약 한 개의 조건

/// 수정 화면이 들고 있는 알약 한 개의 조건. 화면을 닫았다 열어도 이 값을 이어 쓴다.
///
/// **초기 상태와 명시적 되돌리기만 모델값**이다. 값이 같아도 사용자가 입력한 것은 사용자값이다.
public struct PillConditions: Equatable {
    public let model: PillModelOutput
    public private(set) var colors: AppearanceCondition<[PillColorModel]>
    public private(set) var shape: AppearanceCondition<PillShapeModel>
    public private(set) var formulation: AppearanceCondition<PillFormulationModel>
    public private(set) var front: FaceConditions
    public private(set) var back: FaceConditions

    public init(model: PillModelOutput) {
        self.model = model
        self.colors = .all
        self.shape = .all
        self.formulation = .all
        self.front = Self.initialFront(model)
        self.back = FaceConditions()
    }

    /// 앞면 초기값 — 각인은 확신 글자(모델값), 마크는 점수가 임계(각인 있음 0.80 · 없음 0.60) 이상이면 `있음`,
    /// 아니면 `전체`. 구분선은 모델이 없다.
    private static func initialFront(_ model: PillModelOutput) -> FaceConditions {
        FaceConditions(
            imprint: model.frontImprint.map { .value($0, source: .model) } ?? .all,
            dividingLine: .all,
            mark: PillMarkRule.isPresent(score: model.frontMarkScore, imprint: model.frontImprint) ? .present(source: .model) : .all
        )
    }

    // MARK: 외형

    /// 색 메뉴. 빈 선택이면 `전체` 로 돌아간다 — 모델 색으로 되돌리는 것과 같다.
    public mutating func setColors(_ colors: [PillColorModel]) {
        self.colors = colors.isEmpty ? .all : .user(colors)
    }

    /// 모양 메뉴. nil = 맨 위 `전체`(되돌리기).
    public mutating func setShape(_ shape: PillShapeModel?) {
        self.shape = shape.map { .user($0) } ?? .all
    }

    /// 제형 메뉴. nil = 맨 위 `전체`(되돌리기).
    public mutating func setFormulation(_ formulation: PillFormulationModel?) {
        self.formulation = formulation.map { .user($0) } ?? .all
    }

    // MARK: 각인

    /// 입력 줄에서 확인. 비우고 확인하면 `없음`, 글자가 있으면 **모델값과 같아도** 사용자값이다.
    /// 한 글자만 고쳐도 그 면 전체가 사용자값이 된다 — 면 단위 규칙(spec PillFaceRequest.imprintSource).
    public mutating func submitImprint(_ text: String, on face: PillFace) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        update(face) { $0.imprint = trimmed.isEmpty ? .none : .value(trimmed, source: .user) }
    }

    /// 각인 드롭다운에서 `전체` / `없음` 을 고른 경우.
    public mutating func setImprint(_ condition: ImprintCondition, on face: PillFace) {
        update(face) { $0.imprint = condition }
    }

    /// 각인 칸 안의 되돌리기 — 모델 확신 글자가 있으면 그 값(모델값)으로, 없으면 `전체` 로.
    public mutating func revertImprint(on face: PillFace) {
        let initial = face == .front ? Self.initialFront(model).imprint : .all
        update(face) { $0.imprint = initial }
    }

    // MARK: 구분선 · 마크 — 되돌리기는 메뉴에서 다시 고른다

    public mutating func setDividingLine(_ condition: DividingLineCondition, on face: PillFace) {
        update(face) { $0.dividingLine = condition }
    }

    /// 마크 메뉴. `있음` 을 사용자가 고르면 모델값이 아니라 사용자값이다.
    public mutating func setMark(_ condition: MarkCondition, on face: PillFace) {
        update(face) { $0.mark = condition }
    }

    private mutating func update(_ face: PillFace, _ change: (inout FaceConditions) -> Void) {
        switch face {
        case .front: change(&front)
        case .back:  change(&back)
        }
    }

    // MARK: 후보 조회 요청

    /// 후보 조회에 보낼 조건. **사용자가 직접 고른 값만** 담는다 — 모델이 추정한 색·모양·제형은 토큰으로만 간다.
    public var query: PillCandidateQuery {
        PillCandidateQuery(
            attributeToken: model.attributeToken,
            colors: colors.userValue ?? [],
            shape: shape.userValue,
            formulation: formulation.userValue,
            front: Self.faceQuery(front, embedding: model.frontEmbedding),
            back: Self.faceQuery(back, embedding: nil)
        )
    }

    private static func faceQuery(_ face: FaceConditions, embedding: [Float]?) -> PillFaceQuery? {
        let imprint: (String, ValueSource)?
        switch face.imprint {
        case .all:                      imprint = nil
        case .none:                     imprint = ("", .user)
        case .value(let text, let src): imprint = (text, src)
        }

        let dividingLine: PillDividingLineQuery?
        switch face.dividingLine {
        case .all:            dividingLine = nil
        case .none:           dividingLine = PillDividingLineQuery.none
        case .value(.plus):   dividingLine = .plus
        case .value(.minus):  dividingLine = .minus
        case .value(.unknown): dividingLine = nil
        }

        let hasMark: Bool?
        switch face.mark {
        case .all:     hasMark = nil
        case .none:    hasMark = false
        case .present: hasMark = true
        }

        let query = PillFaceQuery(
            imprint: imprint?.0,
            imprintSource: imprint?.1,
            dividingLine: dividingLine,
            hasMark: hasMark,
            embedding: embedding
        )
        return query.isEmpty ? nil : query
    }
}

// MARK: - 후보 조회 조건 (전송용)

/// `POST /api/v1/pill-candidates` 에 보낼 조건. 네트워크 형식(base64 fp16 등)으로의 변환은 Data 계층이 한다.
public struct PillCandidateQuery: Equatable {
    /// 사용자가 무엇을 고쳤든 **항상** 보낸다. 서버가 해석 못 하면(`INVALID_ATTRIBUTE_TOKEN`) 빼고 다시 조회한다.
    public var attributeToken: String?
    /// 사용자가 고른 색만 — 점수. 비면 사용자색 항 없음.
    public var colors: [PillColorModel]
    /// 사용자가 고른 모양만 — 하드 필터.
    public var shape: PillShapeModel?
    /// 사용자가 고른 제형만 — 하드 필터.
    public var formulation: PillFormulationModel?
    public var front: PillFaceQuery?
    public var back: PillFaceQuery?

    public init(
        attributeToken: String?,
        colors: [PillColorModel],
        shape: PillShapeModel?,
        formulation: PillFormulationModel?,
        front: PillFaceQuery?,
        back: PillFaceQuery?
    ) {
        self.attributeToken = attributeToken
        self.colors = colors
        self.shape = shape
        self.formulation = formulation
        self.front = front
        self.back = back
    }

    /// `INVALID_ATTRIBUTE_TOKEN` 재조회용 — 후보는 나오고 정렬만 덜 맞는다. 화면에 따로 표시하지 않는다.
    public var withoutToken: PillCandidateQuery {
        var copy = self
        copy.attributeToken = nil
        return copy
    }
}

public enum PillDividingLineQuery: Equatable {
    case none
    case plus
    case minus
}

public struct PillFaceQuery: Equatable {
    /// `""` = 각인 없는 알약만(사용자값에서만). nil = 조건 없음.
    public var imprint: String?
    /// imprint 가 있으면 반드시 있다(없으면 서버 400).
    public var imprintSource: ValueSource?
    public var dividingLine: PillDividingLineQuery?
    /// true = 있음 · false = 없음(사용자만) · nil = 조건 없음.
    public var hasMark: Bool?
    /// 후보 최종 재정렬용 — 하드 필터가 아니고, 마크 유무 조건(hasMark)과 무관하게 있으면 항상 보낸다.
    /// 요청 필드 이름은 spec 의 `markEmbedding`.
    public var embedding: [Float]?

    public init(
        imprint: String?,
        imprintSource: ValueSource?,
        dividingLine: PillDividingLineQuery?,
        hasMark: Bool?,
        embedding: [Float]?
    ) {
        self.imprint = imprint
        self.imprintSource = imprintSource
        self.dividingLine = dividingLine
        self.hasMark = hasMark
        self.embedding = embedding
    }

    /// 아무 조건도 없으면 면 자체를 보내지 않는다(null = 그 면 조건 제외).
    var isEmpty: Bool {
        imprint == nil && dividingLine == nil && hasMark == nil && embedding == nil
    }
}
