import Foundation

// MARK: - Item Repository Protocol

public protocol ItemRepository: Sendable {
    func fetchItems() async throws -> [Item]
    func fetchItem(id: String) async throws -> Item
}
