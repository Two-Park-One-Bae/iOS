import AppIntents
import Foundation
import TimerDomain

// 각 위젯(잠금화면 슬롯 포함)이 "어떤 프리셋인지"를 자기 설정으로 갖는다 → 슬롯마다 다른 프리셋.
// 프리셋 데이터(라벨·시간)는 App Group 에서 실시간으로 읽으므로 여기선 id·라벨만 갖는다.
public struct TimerPresetEntity: AppEntity {
    public let id: UUID
    public let label: String

    public init(id: UUID, label: String) {
        self.id = id
        self.label = label
    }

    public init(_ preset: TimerPresetModel) {
        self.id = preset.id
        self.label = preset.label
    }

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "프리셋"
    public var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(label)") }
    public static let defaultQuery = TimerPresetQuery()
}

// 선택지 + 기본값 — 저장소에서 동적으로 공급.
public struct TimerPresetQuery: EntityQuery {
    public init() {}

    public func entities(for ids: [UUID]) async throws -> [TimerPresetEntity] {
        TimerPresetStore.loadPresets().filter { ids.contains($0.id) }.map(TimerPresetEntity.init)
    }

    public func suggestedEntities() async throws -> [TimerPresetEntity] {
        TimerPresetStore.loadPresets().map(TimerPresetEntity.init)
    }

    // 미선택 시 nil → 위젯이 "+"(미설정)로 렌더. 사용자가 위젯 편집에서 프리셋을 고른다.
    public func defaultResult() async -> TimerPresetEntity? { nil }
}
