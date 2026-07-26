//
//  MockPillRepository.swift
//  DrugIdentificationFeatureDemo
//
//  Created by 바견규 on 7/5/26.
//

import Combine
import Foundation

import Domain

final class MockPillRepository: PillRepositoryProtocol {

    func fetchPillAttributes(
        items: [(pillId: String, croppedImage: String)]
    ) -> AnyPublisher<PillAttributeResultModel, Error> {
        let stub = items.enumerated().map { index, item -> PillAttributeModel in
            // 두 번째 알약은 색·모양·제형·각인 인식 실패 카드로 반환
            if index == 1 {
                return PillAttributeModel(
                    pillId:        item.pillId,
                    colors:        [],
                    isTransparent: false,
                    shape:         nil,
                    formulation:   nil,
                    front:         nil,
                    back:          nil,
                    error:         "RECOGNITION_FAILED"
                )
            }
            return PillAttributeModel(
                pillId:        item.pillId,
                colors:        [.white, .yellow],
                isTransparent: false,
                shape:         .oval,
                formulation:   .tablet,
                front:         PillFaceModel(imprint: "ABC", dividingLine: .minus, hasMark: false),
                back:          PillFaceModel(imprint: nil, dividingLine: nil, hasMark: false),
                error:         nil
            )
        }
        // 데모는 한도를 소진하지 않는다 — 잔여를 넉넉히 준다. 한도 UI는 fetchPillUsage 스텁으로 확인.
        let result = PillAttributeResultModel(items: stub, usage: Self.stubUsage(remaining: 12))
        return Just(result)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func fetchPillUsage() -> AnyPublisher<PillUsageModel, Error> {
        Just(Self.stubUsage(remaining: 12))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    // remaining을 0으로 바꾸면 한도 소진 상태·안내 팝업을 데모에서 확인할 수 있다.
    private static func stubUsage(remaining: Int) -> PillUsageModel {
        PillUsageModel(
            limit:     15,
            remaining: remaining,
            resetAt:   Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
        )
    }

    func fetchPillCandidates(
        colors: [PillColorModel]?,
        isTransparent: Bool?,
        shape: PillShapeModel?,
        formulation: PillFormulationModel?,
        front: PillFaceModel?,
        back: PillFaceModel?,
        cursor: String?,
        size: Int
    ) -> AnyPublisher<PillCandidatePageModel, Error> {
        // 데모: 투명 알약으로 검색하면 "조건에 맞는 후보가 없어요" 빈 상태를 보여준다.
        // 토글을 끄면 다시 후보가 나타난다.
        if isTransparent == true {
            let empty = PillCandidatePageModel(
                candidates: [],
                nextCursor: nil,
                hasNext:    false
            )
            return Just(empty)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }

        let stub = PillCandidatePageModel(
            candidates: [
                PillCandidateModel(
                    pillCode:      "A11A1234",
                    pillName:      "타이레놀정500밀리그람",
                    companyName:   "한국얀센",
                    pillThumbnailUrl: nil,
                    licenseStatus: .normal
                ),
                PillCandidateModel(
                    pillCode:      "A11A5678",
                    pillName:      "게보린정",
                    companyName:   "삼진제약",
                    pillThumbnailUrl: nil,
                    licenseStatus: .revoked
                ),
                // 세부정보 404 데모 — 이 후보의 ⓘ를 누르면 '데이터 없음' 화면(⑩-e)이 뜬다.
                PillCandidateModel(
                    pillCode:      "A11A9999",
                    pillName:      "세부정보없는약(데모)",
                    companyName:   "데모제약",
                    pillImageUrl:  nil,
                    licenseStatus: .normal
                ),
            ],
            nextCursor: nil,
            hasNext:    false
        )
        return Just(stub)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func fetchPillDetail(pillCode: String) -> AnyPublisher<PillDetailModel, Error> {
        // 데모: A11A9999는 404(PillDetailNotFoundError)를 반환해 '데이터 없음' 화면(⑩-e)을 확인시킨다.
        if pillCode == "A11A9999" {
            return Fail(error: PillDetailNotFoundError())
                .eraseToAnyPublisher()
        }

        // 데모: 타이레놀정500mg 세부정보. 모든 블록 타입(HEADING/PARAGRAPH/TABLE/IMAGE)·표 병합·첨자를 포함.
        func span(_ text: String, _ style: SpanStyleModel? = nil) -> SpanModel {
            SpanModel(text: text, style: style)
        }
        func cell(_ text: String, header: Bool = false, colspan: Int = 1, rowspan: Int = 1) -> TableCellModel {
            TableCellModel(content: [span(text)], colspan: colspan, rowspan: rowspan, header: header)
        }
        // 1x1 투명 PNG (data URI 처리 데모용)
        let sampleImage = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

        let detail = PillDetailModel(
            pillCode:       pillCode,
            name:           "타이레놀정500밀리그람(아세트아미노펜)",
            companyName:    "한국얀센",
            pillImageUrl:   nil,   // 데모: 원본 이미지 없음 — 실제 앱은 서버가 pillCode로 URL 조립.
            classification: .otc,
            appearance:     "흰색의 장방형 필름코팅정, 한쪽 면에 'TYLENOL 500' 각인",
            ingredients:    [IngredientModel(name: "아세트아미노펜", amount: "500", unit: "밀리그램")],
            storageMethod:  "기밀용기, 실온(1~30℃)에서 보관",
            validTerm:      "제조일로부터 36개월",
            packUnit:       "10정/PTP, 100정/병",
            documents: [
                LicenseDocModel(type: .effect, blocks: [
                    .heading(content: [span("효능효과")]),
                    .paragraph(content: [span("다음 증상의 완화: 감기로 인한 발열 및 통증, 두통, 신경통, 근육통, 월경통, 치통, 관절통.")]),
                ]),
                LicenseDocModel(type: .dosage, blocks: [
                    .heading(content: [span("용법용량")]),
                    .paragraph(content: [span("만 12세 이상 소아 및 성인은 1회 1~2정씩, 4~6시간마다 필요시 복용한다.\n1일 최대 4,000mg(8정)을 초과하지 않는다.")]),
                    .table(caption: [span("연령별 용량")], rows: [
                        TableRowModel(cells: [cell("연령", header: true, rowspan: 2), cell("용량", header: true, colspan: 2)]),
                        TableRowModel(cells: [cell("1회", header: true), cell("1일 최대", header: true)]),
                        TableRowModel(cells: [cell("성인"), cell("1~2정"), cell("8정")]),
                        TableRowModel(cells: [cell("만 12세 이상 소아"), cell("1정"), cell("5정")]),
                    ]),
                ]),
                LicenseDocModel(type: .caution, blocks: [
                    .heading(content: [span("사용상의 주의사항")]),
                    .paragraph(content: [span("다른 아세트아미노펜 함유 제제와 병용하지 마십시오.")]),
                    .paragraph(content: [
                        span("혈중 최고 농도 C"), span("max", .sub),
                        span(" 도달 후 반감기 t"), span("1/2", .sub),
                        span("는 약 2~3시간이며, 체표면적 1.73m"), span("2", .sup),
                        span(" 기준으로 조정한다."),
                    ]),
                    .image(src: sampleImage),
                ]),
            ]
        )
        return Just(detail)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
