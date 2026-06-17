import Foundation

// MARK: - Default Item Repository

public final class DefaultItemRepository: ItemRepository, @unchecked Sendable {
    private let networkClient: NetworkProviding

    public init(networkClient: NetworkProviding) {
        self.networkClient = networkClient
    }

    public func fetchItems() async throws -> [Item] {
        // 실제 API 호출 예시:
        // let dtos: [ItemDTO] = try await networkClient.request(.get(path: "/items"))
        // return dtos.map { $0.toEntity() }

        // 템플릿 데모용 — Mock 데이터 반환
        try await Task.sleep(for: .seconds(1))
        return Item.mocks
    }

    public func fetchItem(id: String) async throws -> Item {
        // let dto: ItemDTO = try await networkClient.request(.get(path: "/items/\(id)"))
        // return dto.toEntity()

        try await Task.sleep(for: .milliseconds(500))
        guard let item = Item.mocks.first(where: { $0.id == id }) else {
            throw APIError.httpError(statusCode: 404)
        }
        return item
    }
}

// MARK: - Mock Repository (프리뷰용)

public final class MockItemRepository: ItemRepository, @unchecked Sendable {
    public var mockItems: [Item] = Item.mocks

    public init() {}

    public func fetchItems() async throws -> [Item] {
        mockItems
    }

    public func fetchItem(id: String) async throws -> Item {
        guard let item = mockItems.first(where: { $0.id == id }) else {
            throw APIError.httpError(statusCode: 404)
        }
        return item
    }
}
