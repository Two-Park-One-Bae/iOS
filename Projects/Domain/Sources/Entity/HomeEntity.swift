import Foundation

public struct HomeEntity: Equatable {
    public let id: Int
    public let title: String
    public let description: String
    public let imageURL: String?

    public init(id: Int, title: String, description: String, imageURL: String?) {
        self.id = id
        self.title = title
        self.description = description
        self.imageURL = imageURL
    }
}
