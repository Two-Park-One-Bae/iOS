import Foundation

public struct HomeItemDTO: Decodable {
    public let id: Int
    public let title: String
    public let description: String
    public let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case imageURL = "image_url"
    }
}

public struct HomeListResponseDTO: Decodable {
    public let items: [HomeItemDTO]
}
