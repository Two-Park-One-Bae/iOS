import Foundation

// MARK: - Item DTO (API Response)

struct ItemDTO: Decodable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let imageURLString: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle
        case imageURLString = "image_url"
        case createdAt = "created_at"
    }
}

// MARK: - DTO → Entity 변환

extension ItemDTO {
    func toEntity() -> Item {
        Item(
            id: id,
            title: title,
            subtitle: subtitle,
            imageURL: imageURLString.flatMap { URL(string: $0) },
            createdAt: ISO8601DateFormatter().date(from: createdAt) ?? .now
        )
    }
}
