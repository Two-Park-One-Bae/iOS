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
        // 두 번째 알약은 추출 실패 — 부분 실패가 없어 실패면 나머지가 모두 비어 있다.
        // 데모는 한도를 소진하지 않는다 — 잔여를 넉넉히 준다. 한도 UI는 fetchPillUsage 스텁으로 확인.
        let stub = items.enumerated().map { index, item in
            index == 1
                ? PillAttributeModel(pillId: item.pillId, attributeToken: nil, colorHexes: [],
                                       shape: nil, formulation: nil, error: "EXTRACTION_FAILED")
                : PillAttributeModel(pillId: item.pillId, attributeToken: "demo-token-\(index)",
                                       colorHexes: ["#E6E3DD"], shape: .round, formulation: .tablet, error: nil)
        }
        return Just(PillAttributeResultModel(items: stub, usage: Self.stubUsage(remaining: 12)))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func uploadOriginalImage(_ jpegData: Data) -> AnyPublisher<Void, Error> {
        // 데모: 실제 업로드 없이 성공 처리(베스트 에포트).
        Just(())
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

    // MARK: 후보 (서버 /api/v1 흉내)

    /// 데모 카탈로그 — 앞 셋은 이름 있는 품목, 뒤는 이어 받기(21번째~)를 보이려는 채움. 200개.
    /// 보통은 앞 152개(마크 298개가 모두 나오는 데까지)를, 잘린 결과(truncated)는 서버처럼 200개를 돌려준다.
    private static let catalog: [PillCandidateModel] = {
        let named = [
            PillCandidateModel(
                pillCode: "A11A1234", pillName: "타이레놀정500밀리그람", companyName: "한국얀센",
                pillThumbnailUrl: nil, licenseStatus: .normal,
                front: PillFaceModel(imprint: "TY500", dividingLine: nil, hasMark: false, markCode: nil),
                back: PillFaceModel(imprint: nil, dividingLine: .minus, hasMark: false, markCode: nil)
            ),
            PillCandidateModel(
                pillCode: "A11A5678", pillName: "게보린정", companyName: "삼진제약",
                pillThumbnailUrl: nil, licenseStatus: .revoked,
                front: PillFaceModel(imprint: nil, dividingLine: .plus, hasMark: true, markCode: "r0165"),
                back: PillFaceModel(imprint: "SJ", dividingLine: nil, hasMark: false, markCode: nil)
            ),
            // 세부정보 404 데모 — 이 후보의 ⓘ를 누르면 '데이터 없음' 화면(⑩-e)이 뜬다.
            PillCandidateModel(
                pillCode: "A11A9999", pillName: "세부정보없는약(데모)", companyName: "데모제약",
                pillThumbnailUrl: nil, licenseStatus: .normal
            ),
        ]
        func mark(_ n: Int, _ side: Int) -> String? {
            let index = (n - 4) * 2 + side
            return index < MockPillMarkCodes.all.count ? MockPillMarkCodes.all[index] : nil
        }
        let filler = (4...200).map { n in
            PillCandidateModel(
                pillCode: String(format: "D%07d", n), pillName: "데모 후보 \(n)", companyName: "데모제약",
                pillThumbnailUrl: nil, licenseStatus: .normal,
                // 앞 · 뒷면에 마크를 하나씩 순서대로 — 4~152번 후보가 앱에 넣은 마크 298개를 모두 한 번씩 보인다.
                // 153번 이후는 마크 없음, 99번 뒷면은 앱에 없는 코드(일반 아이콘).
                front: PillFaceModel(imprint: "D\(n)", dividingLine: nil, hasMark: mark(n, 0) != nil,
                                              markCode: mark(n, 0)),
                back: PillFaceModel(imprint: nil, dividingLine: nil, hasMark: n == 99 || mark(n, 1) != nil,
                                             markCode: n == 99 ? "r9999" : mark(n, 1))
            )
        }
        return named + filler
    }()

    /// 그사이 사라진 품목 흉내 — ids 에는 있지만 items 조회에서 missing 으로 돌아온다.
    private static let vanishedCode = String(format: "D%07d", 170)   // 마크 없는 후보 — 마크 전체 보기를 가리지 않게

    struct DemoSearchFailure: Error {}

    /// 이어서 조회 실패 데모 — 마지막 조회에서 뒷면 구분선을 골랐으면 items 조회가 실패한다(다시 시도는 성공).
    private var failNextItems = false

    func fetchPillCandidates(query: PillCandidateQuery) -> AnyPublisher<PillCandidateResultModel, Error> {
        failNextItems = query.back?.dividingLine != nil
        // 데모: 모양 `기타` 를 고르면 0개(빈 상태), 제형 `기타` 를 고르면 조회 실패(다시 시도),
        // 뒷면 구분선을 고르면 이어서 조회(21번째~)가 한 번 실패,
        // 앞면 구분선을 고르면 서버가 200개에서 자른 것처럼(truncated) `+` 헤더와 끝 안내를 보여 준다.
        if query.formulation == .other {
            return Fail(error: DemoSearchFailure())
                .delay(for: .milliseconds(400), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        // 서버는 하드 조건을 통과한 후보가 200개를 넘으면 앞 200개만 ids 로 주고 truncated 를 켠다 —
        // 그 너머는 이어 받을 수 없고, 목록 끝 안내로 조건을 더 좁히게 한다.
        let truncated = query.front?.dividingLine != nil
        let count = query.shape == .other ? 0 : (truncated ? 200 : 152)
        let ids = Self.catalog.prefix(count).map(\.pillCode)
        let result = PillCandidateResultModel(
            ids: ids,
            candidates: Array(Self.catalog.prefix(min(20, count))),
            truncated: truncated && count > 0
        )
        return Just(result)
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func fetchPillCandidateItems(pillCodes: [String]) -> AnyPublisher<PillCandidateItemsModel, Error> {
        if failNextItems {
            failNextItems = false
            return Fail(error: DemoSearchFailure())
                .delay(for: .milliseconds(400), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        // 서버처럼 순서를 보장하지 않는다 — 뒤집어서 돌려준다.
        let found = Self.catalog.filter { pillCodes.contains($0.pillCode) && $0.pillCode != Self.vanishedCode }
        let missing = pillCodes.filter { $0 == Self.vanishedCode }
        return Just(PillCandidateItemsModel(items: found.reversed(), missing: missing))
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(600), scheduler: DispatchQueue.main)
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
