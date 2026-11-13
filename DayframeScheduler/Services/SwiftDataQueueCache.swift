import Foundation
import SwiftData

protocol QueueCaching {
    func store(_ posts: [Post])
    func load() -> [Post]
}

/// SwiftData-backed queue cache: lazily initialized on first access,
/// replaced on every successful fetch, served when the network fails (offline read-only).
final class SwiftDataQueueCache: QueueCaching, @unchecked Sendable {
    private let inMemory: Bool
    private var _container: ModelContainer?
    private let lock = NSLock()

    private var container: ModelContainer {
        lock.lock()
        defer { lock.unlock() }
        if let existing = _container {
            return existing
        }
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        let created = (try? ModelContainer(
            for: CachedPost.self,
            configurations: configuration
        )) ?? (try! ModelContainer(
            for: CachedPost.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        ))
        _container = created
        return created
    }

    init(inMemory: Bool = false) {
        self.inMemory = inMemory
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
