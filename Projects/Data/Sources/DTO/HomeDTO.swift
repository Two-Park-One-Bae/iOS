import Foundation

struct HomeItemDTO: Decodable {
    let id: Int
    let title: String
    let description: String
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case imageURL = "image_url"
    }
}

struct HomeListResponseDTO: Decodable {
    let items: [HomeItemDTO]
}
