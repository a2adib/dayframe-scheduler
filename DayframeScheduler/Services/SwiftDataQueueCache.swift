import Foundation
import SwiftData

protocol QueueCaching {
    func store(_ posts: [Post])
    func load() -> [Post]
}

/// SwiftData-backed queue cache: replaced on every successful fetch, served
/// when the network fails (offline read-only).
struct SwiftDataQueueCache: QueueCaching {
    private let container: ModelContainer

    init(inMemory: Bool = false) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = (try? ModelContainer(
            for: CachedPost.self,
            configurations: configuration
        )) ?? {
            let fallback = try! ModelContainer(
                for: CachedPost.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            return fallback
        }()
    }

    func store(_ posts: [Post]) {
        let context = ModelContext(container)
        try? context.delete(model: CachedPost.self)
        for post in posts {
            context.insert(CachedPost(
                postID: post.id,
                body: post.body,
                status: post.status.rawValue,
                scheduledAt: post.scheduledAt,
                platforms: [],
                mediaCaption: post.media.first?.storagePath
            ))
        }
        try? context.save()
    }

    func load() -> [Post] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedPost>(
            sortBy: [SortDescriptor(\.scheduledAt, order: .forward)]
        )
        return (try? context.fetch(descriptor).map(\.post)) ?? []
    }
}
