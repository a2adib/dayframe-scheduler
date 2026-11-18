import Foundation

protocol EngagementRepository {
    func loadItems() async throws -> [EngagementItem]
    func sendReply(itemID: UUID, replyText: String) async throws -> EngagementItem
    func toggleStar(itemID: UUID) async throws -> EngagementItem
    func markReplied(itemID: UUID, isReplied: Bool) async throws -> EngagementItem
}
