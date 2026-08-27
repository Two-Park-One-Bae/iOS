import Combine
import Foundation

import Domain

/// 홈 데모용 PillUseCase 스텁.
///
/// 홈은 남은 횟수 표시·진입 게이트만 쓰므로 `pillUsage`만 의미 있게 채운다.
/// `remaining`을 0으로 바꾸면 한도 소진 표시(경고색)와 카드 탭 시 안내 팝업을 확인할 수 있다.
final class MockPillUseCase: PillUseCase {

    let pillAttributes = PassthroughSubject<[PillAttributeModel], Never>()
    let pillCandidates = PassthroughSubject<PillCandidatePageModel, Never>()
    let pillDetail     = PassthroughSubject<PillDetailModel, Never>()
    let errorMessage   = PassthroughSubject<String, Never>()
    let pillUsage      = CurrentValueSubject<PillUsageModel?, Never>(nil)
    let limitExceeded  = PassthroughSubject<PillUsageModel?, Never>()
    let pillDetailNotFound = PassthroughSubject<Void, Never>()
    let pillDetailFailure  = PassthroughSubject<String, Never>()

    private let remaining: Int

    init(remaining: Int = 12) {
        self.remaining = remaining
    }

    func fetchPillUsage() {
        pillUsage.send(
            PillUsageModel(
                limit:     15,
                remaining: remaining,
                resetAt:   Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
            )
        )
    }

    func resetAccountScopedState() {
        pillUsage.send(nil)
    }

    func fetchPillAttributes(
        items: [(pillId: String, croppedImage: String)]
    ) {}

    func uploadOriginalImage(_ jpegData: Data) {}

    func fetchPillCandidates(
        colors: [PillColorModel]?,
        isTransparent: Bool?,
        shape: PillShapeModel?,
        formulation: PillFormulationModel?,
        front: PillFaceModel?,
        back: PillFaceModel?,
        cursor: String?,
        size: Int
    ) {}

    func fetchPillDetail(pillCode: String) {}
}
