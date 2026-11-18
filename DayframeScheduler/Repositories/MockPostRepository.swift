import Foundation

final class MockPostRepository: PostRepository {
    private var posts: [Post]

    init(posts: [Post] = MockData.posts()) {
        self.posts = posts
    }

    func loadQueue() async throws -> [Post] {
        posts
            .filter { $0.status != .draft && $0.scheduledAt != nil }
            .sorted { ($0.scheduledAt ?? .distantPast) < ($1.scheduledAt ?? .distantPast) }
    }

    func loadPosts(on date: Date) async throws -> [Post] {
        let calendar = Calendar.current
        return try await loadQueue().filter { post in
            calendar.isDate(post.scheduledAt ?? .distantPast, inSameDayAs: date)
        }
    }

    func loadDrafts() async throws -> [Post] {
        posts.filter { $0.status == .draft }
    }

    func save(_ post: Post, as status: PostStatus, scheduleMode: ScheduleMode?, scheduledAt: Date?) async throws -> Post {
        var stored = post
        stored.id = UUID()
        stored.scheduleMode = status == .draft ? nil : scheduleMode
        stored.scheduledAt = scheduledAt
        stored.status = status
        stored.targets = post.targets.map { target in
            var t = target
            t.id = UUID()
            t.status = stored.status
            t.scheduledAt = scheduledAt
            return t
        }
        posts.append(stored)
        return stored
    }

    func update(_ post: Post, as status: PostStatus, scheduleMode: ScheduleMode?, scheduledAt: Date?) async throws -> Post {
        var updated = post
        updated.status = status
        updated.scheduleMode = status == .draft ? nil : scheduleMode
        updated.scheduledAt = scheduledAt
        // Mirror the live repository: published/publishing targets are never reset.
        let existing = posts.first(where: { $0.id == post.id })?.targets ?? []
        let locked = Dictionary(
            existing.filter { $0.status == .published || $0.status == .publishing }.map { ($0.channelID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        updated.targets = post.targets.map { target in
            if let kept = locked[target.channelID] { return kept }
            var t = target
            t.status = status
            t.scheduledAt = scheduledAt
            return t
        }
        posts = posts.map { $0.id == post.id ? updated : $0 }
        return updated
    }

    func retry(_ post: Post) async throws -> Post {
        var retried = post
        retried.status = .scheduled
        retried.scheduledAt = .now
        retried.targets = post.targets.map { target in
            guard target.status == .failed else { return target }
            var t = target
            t.status = .scheduled
            t.scheduledAt = .now
            t.attempts = 0
            t.errorMessage = nil
            return t
        }
        posts = posts.map { $0.id == post.id ? retried : $0 }
        return retried
    }

    func duplicate(_ post: Post) async throws -> Post {
        var copy = post
        copy.id = UUID()
        copy.targets = post.targets.map { var t = $0; t.id = UUID(); return t }
        copy.media = post.media.map { var m = $0; m.id = UUID(); return m }
        posts.append(copy)
        return copy
    }

    func delete(_ post: Post) async throws {
        posts.removeAll { $0.id == post.id }
    }

    func reschedule(_ post: Post, to date: Date) async throws -> Post {
        var updated = post
        updated.scheduledAt = date
        posts = posts.map { $0.id == post.id ? updated : $0 }
        return updated
    }

    func reorderQueue(posts newOrder: [Post]) async throws {
        // Collect existing scheduled times in order
        let existingDates = self.posts
            .filter { $0.status != .draft && $0.scheduledAt != nil }
            .compactMap(\.scheduledAt)
            .sorted()

        var reorderedMap: [UUID: Date] = [:]
        for (index, post) in newOrder.enumerated() {
            if index < existingDates.count {
                reorderedMap[post.id] = existingDates[index]
            }
        }

        self.posts = self.posts.map { post in
            if let newDate = reorderedMap[post.id] {
                var p = post
                p.scheduledAt = newDate
                p.targets = p.targets.map { var t = $0; t.scheduledAt = newDate; return t }
                return p
            }
            return post
        }
    }

    func attachMedia(_ data: Data, fileName: String, kind: MediaKind, to post: Post) async throws -> MediaAsset {
        let position = posts.first(where: { $0.id == post.id })?.media.count ?? 0
        let asset = MediaAsset(
            id: UUID(), storagePath: "mock/\(post.id)/\(fileName)",
            kind: kind, width: nil, height: nil, durationMS: nil, position: position
        )
        posts = posts.map { stored in
            var updated = stored
            if updated.id == post.id { updated.media.append(asset) }
            return updated
        }
        return asset
    }
}
