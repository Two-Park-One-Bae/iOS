import Combine
import XCTest
import Core
import Domain
@testable import DrugIdentificationFeature

/// 수정 화면을 다시 열어도 수정 기록이 이어지는가 (NM-535).
final class PillEditRecordTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // PillEditViewModel 은 @Injected 로 PillUseCase 를 꺼낸다 — 테스트엔 조립 지점이 없어 스텁을 넣는다.
        DIContainer.shared.register(PillUseCase.self) { StubPillUseCase() }
    }

    // 수동 추가로 만든다 — 기록은 똑같이 쌓이고 pill_attr_edit 은 보내지 않는다.
    private func viewModel(record: PillEditRecord = PillEditRecord()) -> PillEditViewModel {
        PillEditViewModel(pillIndex: 1, displayNumber: 1, conditions: PillConditions(model: .empty),
                          editRecord: record, thumbnail: nil, isManual: true)
    }

    func test_수정이_없으면_0회_none() {
        let vm = viewModel()
        XCTAssertEqual(vm.editCount, 0)
        XCTAssertEqual(vm.editedAttrsJoined, "none")
    }

    func test_다시_열면_앞선_방문의_기록에서_이어_센다() {
        let first = viewModel()
        first.setDividingLine(.none, on: .front)
        first.setMark(.none, on: .front)

        let reopened = viewModel(record: first.editRecordSubject.value)
        XCTAssertEqual(reopened.editCount, 2)
        XCTAssertEqual(reopened.editedAttrsJoined, "dividing_line,mark")

        reopened.setShape(.round)
        XCTAssertEqual(reopened.editCount, 3)
        XCTAssertEqual(reopened.editedAttrsJoined, "dividing_line,mark,shape")
    }

    func test_같은_값으로_바꾸면_세지_않는다() {
        let vm = viewModel()
        vm.setShape(nil)   // 이미 전체
        XCTAssertEqual(vm.editCount, 0)
    }
}

/// 아무것도 하지 않고 아무것도 방출하지 않는다 — 여기서 보는 건 수정 기록뿐이다.
private final class StubPillUseCase: PillUseCase {
    let pillAttributes = PassthroughSubject<[PillAttributeModel], Never>()
    let pillDetail = PassthroughSubject<PillDetailModel, Never>()
    let errorMessage = PassthroughSubject<String, Never>()
    let pillUsage = CurrentValueSubject<PillUsageModel?, Never>(nil)
    let limitExceeded = PassthroughSubject<PillUsageModel?, Never>()
    let pillDetailNotFound = PassthroughSubject<Void, Never>()
    let pillDetailFailure = PassthroughSubject<String, Never>()

    func fetchPillAttributes(items: [(pillId: String, croppedImage: String)]) {}
    func uploadOriginalImage(_ jpegData: Data) {}
    func fetchPillCandidates(query: PillCandidateQuery) -> AnyPublisher<PillCandidateResultModel, Error> {
        Empty().eraseToAnyPublisher()
    }
    func fetchPillCandidateItems(pillCodes: [String]) -> AnyPublisher<PillCandidateItemsModel, Error> {
        Empty().eraseToAnyPublisher()
    }
    func fetchPillDetail(pillCode: String) {}
    func fetchPillUsage() {}
    func resetAccountScopedState() {}
}
