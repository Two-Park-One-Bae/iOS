import Domain

extension HomeItemDTO {
    func toDomain() -> HomeEntity {
        HomeEntity(
            id: id,
            title: title,
            description: description,
            imageURL: imageURL
        )
    }
}
