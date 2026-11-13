import Foundation

final class MockPostRepository: PostRepository {
    private var posts: [Post]

    init(posts: [Post] = MockData.posts()) {
        self.posts = posts
    }

    func loadQueue() async throws -> [Post] {
        posts
            .filter { $0.status == .scheduled && $0.scheduledAt != nil }
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
}
