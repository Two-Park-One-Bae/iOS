import Combine
import UIKit
import Core
import Domain
import SegmentationKit

public final class DrugIdentificationViewModel {

    // MARK: - State

    enum State {
        case loading
        case success(pills: [IdentifiedPill], image: UIImage)
        case empty
        case failure(message: String)
        // 한도 도달(429) — 분석 실패 화면이 아니라 안내 팝업으로 분기한다 (NM-323)
        case limitExceeded(usage: PillUsageModel?)
    }

    // MARK: - Input / Output

    public struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
    }

    struct Output {
        let state: AnyPublisher<State, Never>
    }

    // MARK: - Dependencies

    @Injected private var pillUseCase: PillUseCase

    private let image: UIImage
    private let scoreThreshold: Float = 0.5
    private var cancelBag = Set<AnyCancellable>()

    private let stateSubject = CurrentValueSubject<State, Never>(.loading)

    // MARK: - Init

    init(image: UIImage) {
        self.image = image
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        input.viewDidLoad
            .sink { [weak self] in self?.identify() }
            .store(in: &cancelBag)

        return Output(state: stateSubject.eraseToAnyPublisher())
    }

    // MARK: - Pipeline

    private func identify() {
        bindUseCase()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let segmentor: RFDetrSegmentor
            do {
                segmentor = try RFDetrSegmentor()
            } catch {
                self.emit(.failure(message: error.localizedDescription))
                return
            }

            do {
                let result = try segmentor.run(image: self.image)
                let detections = result.detections
                    .filter { $0.score >= self.scoreThreshold }
                    .sorted { $0.box.minX < $1.box.minX }

                guard !detections.isEmpty else {
                    self.emit(.empty)
                    return
                }

                let pills = self.makeIdentifiedPills(from: detections)
                self.pending = (pills, self.buildItems(from: pills))
                self.requestAttributes(items: self.pending?.items ?? [])
            } catch {
                self.emit(.failure(message: error.localizedDescription))
            }
        }
    }

    // 세그멘테이션으로 얻은 크롭 결과를 임시 보관 (속성 응답과 결합)
    private var pending: (pills: [IdentifiedPill], items: [(pillId: String, croppedImage: String)])?

    private func makeIdentifiedPills(from detections: [RFDetection]) -> [IdentifiedPill] {
        // 크롭은 원본 정규화 1회로 일괄 생성(detection마다 재렌더하던 것 제거).
        let crops = RFDetrSegmentor.croppedImages(from: image, detections: detections)
        return detections.enumerated().map { offset, detection in
            let placeholder = PillAttributeModel(
                pillId: "\(detection.id)",
                colors: [], isTransparent: false,
                shape: nil, formulation: nil,
                front: nil, back: nil, error: nil
            )
            return IdentifiedPill(
                index: offset + 1,
                thumbnail: crops[offset],
                boundingBox: detection.box,
                attribute: placeholder
            )
        }
    }

    private func buildItems(
        from pills: [IdentifiedPill]
    ) -> [(pillId: String, croppedImage: String)] {
        pills.map { pill in
            // 인코딩 임시 버퍼(PNG Data·base64 String)를 즉시 해제.
            let base64 = autoreleasepool { pill.thumbnail?.pngData()?.base64EncodedString() ?? "" }
            return (pillId: pill.attribute.pillId, croppedImage: base64)
        }
    }

    private func requestAttributes(
        items: [(pillId: String, croppedImage: String)]
    ) {
        // 원본은 학습데이터용으로 S3에 별도 업로드(베스트 에포트, NM-348) — 식별과 분리·병렬, 실패 무시.
        // 내부 빌드(개발자 테스트)는 학습 데이터셋 오염 방지를 위해 업로드하지 않는다.
        if !AppEnvironment.isInternal,
           let jpeg = autoreleasepool(invoking: { image.jpegData(compressionQuality: 0.9) }) {
            pillUseCase.uploadOriginalImage(jpeg)
        }
        pillUseCase.fetchPillAttributes(items: items)
    }

    private func bindUseCase() {
        // pill_identify_result — 시도당 최종 결과 1회 집계(식별 성공률의 분모).
        // 종료 상태가 여러 지점(세그멘테이션 실패/빈검출/속성병합/에러/한도)에서 방출되므로,
        // stateSubject 를 한 곳에서 구독해 '첫' 종료만 발사한다. loading 은 통과,
        // limitExceeded 는 제외(별도 pill_limit_reached).
        stateSubject
            .compactMap { state -> AnalyticsEvent? in
                switch state {
                case let .success(pills, _): return .pillIdentifyResult(outcome: "success", pillCount: pills.count)
                case .empty:                 return .pillIdentifyResult(outcome: "empty", pillCount: 0)
                case .failure:               return .pillIdentifyResult(outcome: "failure", pillCount: 0)
                case .loading, .limitExceeded: return nil
                }
            }
            .first()
            .sink { AppAnalytics.track($0) }
            .store(in: &cancelBag)

        // pill_limit_reached — 마지막 1회를 쓴 요청이 성공으로 돌아온 순간(잔여 0) 1회.
        //
        // 서버가 이번 요청이 반영된 잔여를 응답에 실어 주므로(API 0.13.0 `{ items, usage }`),
        // PillUseCase 가 pillAttributes 를 방출하기 직전 pillUsage 를 갱신해 둔다.
        // 따라서 success/empty 상태가 뜬 시점의 pillUsage 는 곧 '이번 요청 후 잔여'다.
        // failure 는 서버가 처리하지 못한 것이라 잔여가 갱신되지 않으므로 제외한다.
        stateSubject
            .filter { state in
                switch state {
                case .success, .empty:                   return true
                case .loading, .failure, .limitExceeded: return false
                }
            }
            .first()
            .sink { [weak self] _ in
                guard self?.pillUseCase.pillUsage.value?.remaining == 0 else { return }
                AppAnalytics.track(.pillLimitReached(source: "exhausted"))
            }
            .store(in: &cancelBag)

        pillUseCase.pillAttributes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] attributes in
                guard let self, let pending = self.pending else { return }
                let merged = self.merge(pills: pending.pills, with: attributes)
                if merged.isEmpty {
                    self.stateSubject.send(.empty)
                } else {
                    self.stateSubject.send(.success(pills: merged, image: self.image))
                }
            }
            .store(in: &cancelBag)

        pillUseCase.errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.stateSubject.send(.failure(message: message))
            }
            .store(in: &cancelBag)

        pillUseCase.limitExceeded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] usage in
                self?.stateSubject.send(.limitExceeded(usage: usage))
            }
            .store(in: &cancelBag)
    }

    // 속성 응답을 pillId 기준으로 크롭 결과와 병합
    private func merge(
        pills: [IdentifiedPill],
        with attributes: [PillAttributeModel]
    ) -> [IdentifiedPill] {
        let byId = Dictionary(attributes.map { ($0.pillId, $0) }, uniquingKeysWith: { first, _ in first })
        return pills.map { pill in
            guard let attribute = byId[pill.attribute.pillId] else { return pill }
            return IdentifiedPill(
                index: pill.index,
                thumbnail: pill.thumbnail,
                boundingBox: pill.boundingBox,
                attribute: attribute
            )
        }
    }

    private func emit(_ state: State) {
        DispatchQueue.main.async { [weak self] in
            self?.stateSubject.send(state)
        }
    }
}
