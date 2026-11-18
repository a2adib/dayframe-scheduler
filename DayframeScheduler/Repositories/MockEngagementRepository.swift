import Foundation

final class MockEngagementRepository: EngagementRepository {
    private var items: [EngagementItem]

    init(items: [EngagementItem]? = nil) {
        if let items {
            self.items = items
        } else {
            let chInstagram = MockData.channels.first(where: { $0.platform == .instagram })?.id ?? UUID()
            let chX = MockData.channels.first(where: { $0.platform == .x })?.id ?? UUID()
            let chLinkedIn = MockData.channels.first(where: { $0.platform == .linkedin })?.id ?? UUID()

            self.items = [
                EngagementItem(
                    id: UUID(),
                    channelID: chInstagram,
                    postID: nil,
                    postSnippet: "Morning rhythm check: framing your day before opening your feeds changes everything...",
                    authorName: "Sarah Lin",
                    authorHandle: "@sarahlin_designs",
                    authorAvatarURL: nil,
                    content: "Love this approach! How do you handle spontaneous posts alongside scheduled queues?",
                    platform: .instagram,
                    isReplied: false,
                    isStarred: true,
                    replyText: nil,
                    repliedAt: nil,
                    createdAt: .now.addingTimeInterval(-1800)
                ),
                EngagementItem(
                    id: UUID(),
                    channelID: chX,
                    postID: nil,
                    postSnippet: "Quick breakdown of our new content pipeline. Batching on Mondays gives you back 6 hours...",
                    authorName: "Marcus Vance",
                    authorHandle: "@marcus_v",
                    authorAvatarURL: nil,
                    content: "This routine literally saved my mornings last week. Highly recommend framing the day first!",
                    platform: .x,
                    isReplied: true,
                    isStarred: false,
                    replyText: "Appreciate you sharing that Marcus! Consistency becomes easy when the system does the heavy lifting.",
                    repliedAt: .now.addingTimeInterval(-3600),
                    createdAt: .now.addingTimeInterval(-7200)
                ),
                EngagementItem(
                    id: UUID(),
                    channelID: chLinkedIn,
                    postID: nil,
                    postSnippet: "Behind the scenes of the studio refresh — new lights, new backdrop, same chaos...",
                    authorName: "Elena Rostova",
                    authorHandle: "in/elena-rostova",
                    authorAvatarURL: nil,
                    content: "What lighting setup are you using for the soft background fill? The warmth in your video looks phenomenal.",
                    platform: .linkedin,
                    isReplied: false,
                    isStarred: false,
                    replyText: nil,
                    repliedAt: nil,
                    createdAt: .now.addingTimeInterval(-14400)
                ),
                EngagementItem(
                    id: UUID(),
                    channelID: chInstagram,
                    postID: nil,
                    postSnippet: "Morning rhythm check: framing your day before opening your feeds changes everything...",
                    authorName: "Alex Rivera",
                    authorHandle: "@alexrivera.studio",
                    authorAvatarURL: nil,
                    content: "Can you drop the template or tool you use to map out your weekly slots?",
                    platform: .instagram,
                    isReplied: false,
                    isStarred: true,
                    replyText: nil,
                    repliedAt: nil,
                    createdAt: .now.addingTimeInterval(-21600)
                )
            ]
        }
    }

    func loadItems() async throws -> [EngagementItem] {
        items.sorted { $0.createdAt > $1.createdAt }
    }

    func sendReply(itemID: UUID, replyText: String) async throws -> EngagementItem {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            throw AppError.network("Item not found")
        }
        var updated = items[index]
        updated.isReplied = true
        updated.replyText = replyText
        updated.repliedAt = .now
        items[index] = updated
        return updated
    }

    func toggleStar(itemID: UUID) async throws -> EngagementItem {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            throw AppError.network("Item not found")
        }
        var updated = items[index]
        updated.isStarred.toggle()
        items[index] = updated
        return updated
    }

    func markReplied(itemID: UUID, isReplied: Bool) async throws -> EngagementItem {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            throw AppError.network("Item not found")
        }
        var updated = items[index]
        updated.isReplied = isReplied
        if !isReplied {
            updated.replyText = nil
            updated.repliedAt = nil
        }
        items[index] = updated
        return updated
    }
}
