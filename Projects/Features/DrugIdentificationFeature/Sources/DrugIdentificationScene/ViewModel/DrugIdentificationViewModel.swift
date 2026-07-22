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
    private var pending: (pills: [IdentifiedPill], items: [(pillId: String, segmentation: [[Double]], croppedImage: String)])?

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
    ) -> [(pillId: String, segmentation: [[Double]], croppedImage: String)] {
        pills.map { pill in
            let box = pill.boundingBox
            let polygon: [[Double]] = [
                [Double(box.minX), Double(box.minY)],
                [Double(box.maxX), Double(box.minY)],
                [Double(box.maxX), Double(box.maxY)],
                [Double(box.minX), Double(box.maxY)]
            ]
            // 인코딩 임시 버퍼(PNG Data·base64 String)를 즉시 해제.
            let base64 = autoreleasepool { pill.thumbnail?.pngData()?.base64EncodedString() ?? "" }
            return (pillId: pill.attribute.pillId, segmentation: polygon, croppedImage: base64)
        }
    }

    private func requestAttributes(
        items: [(pillId: String, segmentation: [[Double]], croppedImage: String)]
    ) {
        let base64 = autoreleasepool { image.jpegData(compressionQuality: 0.9)?.base64EncodedString() ?? "" }
        pillUseCase.fetchPillAttributes(originalImage: base64, items: items)
    }

    private func bindUseCase() {
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
