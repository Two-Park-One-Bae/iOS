import Foundation

public struct Item: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let imageURL: URL?
    public let createdAt: Date

    public init(
        id: String,
        title: String,
        subtitle: String,
        imageURL: URL?,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.createdAt = createdAt
    }

    public static let mocks: [Item] = [
        Item(
            id: "1",
            title: "첫 번째 아이템",
            subtitle: "SwiftUI + MVVM 예제",
            imageURL: nil,
            createdAt: .now
        ),
        Item(
            id: "2",
            title: "두 번째 아이템",
            subtitle: "Tuist 프로젝트 템플릿",
            imageURL: nil,
            createdAt: .now.addingTimeInterval(-3600)
        ),
        Item(
            id: "3",
            title: "세 번째 아이템",
            subtitle: "최신 아키텍처 적용",
            imageURL: nil,
            createdAt: .now.addingTimeInterval(-7200)
        ),
    ]
}
