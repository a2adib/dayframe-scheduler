import Testing
import Foundation
@testable import DayframeScheduler
import Supabase

/// End-to-end Phase 4 verification against the local Supabase stack
/// (`supabase start` must be running): sign up a fresh user, then create,
/// schedule, load, reschedule, and delete posts through the Live repositories.
@MainActor
struct LiveDataLayerTests {
    private func makeStack() async throws -> (AppEnvironment, AuthUser) {
        let environment = AppEnvironment(mode: .live)
        let email = "test-\(Int.random(in: 100_000...999_999))@dayframe.test"
        let user = try await environment.signUpWithTestUser(email: email, password: "dayframe-test-123")
        return (environment, user)
    }

    @Test
    func signUpCreateScheduleRescheduleDelete() async throws {
        let (environment, user) = try await makeStack()
        #expect(user.email.hasSuffix("@dayframe.test"))

        // A fresh user has no channels; create one directly through the
        // client (OAuth connect lands in Phase 5).
        let liveChannelRepository = environment.channelRepository as? LiveChannelRepository
        #expect(liveChannelRepository != nil)

        // The live queue starts empty.
        let queue0 = try await environment.postRepository.loadQueue()
        #expect(queue0.isEmpty)

        // Create and schedule a post (targets need a channel; without one the
        // post is created without targets, matching the schema).
        let scheduledAt = Calendar.current.date(byAdding: .hour, value: 2, to: .now)!
        let post = Post(
            id: UUID(),
            body: "End-to-end test post",
            status: .scheduled,
            scheduleMode: .custom,
            scheduledAt: scheduledAt,
            publishedAt: nil,
            targets: [],
            media: []
        )
        let saved = try await environment.postRepository.save(
            post, as: .scheduled, scheduleMode: .custom, scheduledAt: scheduledAt
        )
        #expect(saved.status == .scheduled)

        var queue = try await environment.postRepository.loadQueue()
        #expect(queue.count == 1)
        #expect(queue.first?.body == "End-to-end test post")

        // Reschedule.
        let newDate = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        let rescheduled = try await environment.postRepository.reschedule(saved, to: newDate)
        #expect(Calendar.current.isDate(rescheduled.scheduledAt ?? .distantPast, inSameDayAs: newDate))
        queue = try await environment.postRepository.loadQueue()
        #expect(queue.first?.scheduledAt != nil)

        // Delete and confirm the queue is empty again.
        try await environment.postRepository.delete(rescheduled)
        queue = try await environment.postRepository.loadQueue()
        #expect(queue.isEmpty)
    }

    @Test
    func mediaUploadEndToEnd() async throws {
        let (environment, _) = try await makeStack()
        let scheduledAt = Calendar.current.date(byAdding: .hour, value: 3, to: .now)!
        let post = Post(
            id: UUID(), body: "Media upload test", status: .scheduled, scheduleMode: .custom,
            scheduledAt: scheduledAt, publishedAt: nil, targets: [], media: []
        )
        let saved = try await environment.postRepository.save(
            post, as: .scheduled, scheduleMode: .custom, scheduledAt: scheduledAt
        )

        // 1x1 transparent PNG.
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
        let asset = try await environment.postRepository.attachMedia(
            png, fileName: "pixel.png", kind: .image, to: saved
        )
        #expect(asset.storagePath.hasSuffix(".png"))
        #expect(asset.storagePath.contains(saved.id.uuidString.lowercased()))
        #expect(asset.position == 0)

        let queue = try await environment.postRepository.loadQueue()
        #expect(queue.first(where: { $0.id == saved.id })?.media.count == 1)

        try await environment.postRepository.delete(saved)
    }

    @Test
    func offlineFallbackServesCache() async throws {
        // A live repository pointed at a dead URL falls back to the cache.
        let deadClient = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:1")!,
            supabaseKey: "test"
        )
        let cacheStub = InMemoryQueueCache(posts: [Post(
            id: UUID(), body: "cached", status: .scheduled, scheduleMode: nil,
            scheduledAt: .now, publishedAt: nil, targets: [], media: []
        )])
        let repository = LivePostRepository(client: deadClient, cache: cacheStub)
        let posts = try await repository.loadQueue()
        #expect(posts.first?.body == "cached")
    }
}

extension AppEnvironment {
    /// Signs up through the auth service and records the session user.
    @MainActor
    func signUpWithTestUser(email: String, password: String) async throws -> AuthUser {
        try await signUp(email: email, password: password)
    }
}

struct InMemoryQueueCache: QueueCaching {
    var posts: [Post]

    func store(_ posts: [Post]) {}
    func load() -> [Post] { posts }
}
