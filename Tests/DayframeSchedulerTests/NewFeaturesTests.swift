import Testing
import Foundation
@testable import DayframeScheduler

@MainActor
struct NewFeaturesTests {

    @Test
    func postRepositoryUpdateAndRetry() async throws {
        let repo = MockPostRepository()

        // 1. Initial post
        let post = Post(
            id: UUID(),
            body: "Original draft",
            status: .draft,
            scheduleMode: nil,
            scheduledAt: nil,
            publishedAt: nil,
            targets: [],
            media: []
        )
        let saved = try await repo.save(post, as: .draft, scheduleMode: nil, scheduledAt: nil)
        #expect(saved.status == .draft)

        // 2. Update post
        var toUpdate = saved
        toUpdate.body = "Updated scheduled post"
        let scheduledTime = Calendar.current.date(byAdding: .hour, value: 5, to: .now)!
        let updated = try await repo.update(toUpdate, as: .scheduled, scheduleMode: .custom, scheduledAt: scheduledTime)
        #expect(updated.body == "Updated scheduled post")
        #expect(updated.status == .scheduled)
        #expect(updated.scheduledAt != nil)

        // 3. Mark as failed and retry
        var failedPost = updated
        failedPost.status = .failed
        failedPost.targets = [
            PostTarget(
                id: UUID(),
                channelID: UUID(),
                bodyOverride: nil,
                status: .failed,
                scheduledAt: scheduledTime,
                publishedAt: nil,
                attempts: 3,
                errorMessage: "Container error"
            )
        ]

        let retried = try await repo.retry(failedPost)
        #expect(retried.status == .scheduled)
        #expect(retried.targets.first?.status == .scheduled)
        #expect(retried.targets.first?.attempts == 0)
        #expect(retried.targets.first?.errorMessage == nil)
    }

    @Test
    func composerPlatformOverridesAndLimits() async throws {
        let channelRepo = MockChannelRepository()
        let postRepo = MockPostRepository()
        let scheduleRepo = MockScheduleRepository()

        let vm = ComposerViewModel(
            channelRepository: channelRepo,
            postRepository: postRepo,
            scheduleRepository: scheduleRepo
        )
        await vm.load()

        #expect(!vm.channels.isEmpty)

        // Set base text
        vm.bodyText = "Base announcement text"
        #expect(vm.bodyFor(platform: .x) == "Base announcement text")
        #expect(!vm.hasOverride(for: .x))

        // Set custom override for X
        vm.setOverride("Punchy tweet for X #buildinpublic", for: .x)
        #expect(vm.hasOverride(for: .x))
        #expect(vm.bodyFor(platform: .x) == "Punchy tweet for X #buildinpublic")
        #expect(vm.bodyFor(platform: .linkedin) == "Base announcement text")

        // Over-limit validation
        let longXText = String(repeating: "A", count: 300)
        vm.setOverride(longXText, for: .x)
        let isValid = vm.validate()
        #expect(!isValid)
        #expect(vm.validationError?.contains("280 characters") == true)
        #expect(vm.validationError?.contains("X (Twitter)") == true)

        // Clearing override
        vm.clearOverride(for: .x)
        #expect(!vm.hasOverride(for: .x))
        #expect(vm.bodyFor(platform: .x) == "Base announcement text")
    }

    @Test
    func queueDraftsAndFailedFilter() async throws {
        let channelRepo = MockChannelRepository()
        let postRepo = MockPostRepository(posts: [
            Post(
                id: UUID(),
                body: "Scheduled Post",
                status: .scheduled,
                scheduleMode: .queue,
                scheduledAt: .now.addingTimeInterval(3600),
                publishedAt: nil,
                targets: [],
                media: []
            ),
            Post(
                id: UUID(),
                body: "Draft Idea",
                status: .draft,
                scheduleMode: nil,
                scheduledAt: nil,
                publishedAt: nil,
                targets: [],
                media: []
            ),
            Post(
                id: UUID(),
                body: "Failed Post",
                status: .failed,
                scheduleMode: .now,
                scheduledAt: .now,
                publishedAt: nil,
                targets: [],
                media: []
            )
        ])

        let vm = QueueViewModel(channelRepository: channelRepo, postRepository: postRepo)
        await vm.load()

        #expect(vm.drafts.count == 1)
        #expect(vm.drafts.first?.body == "Draft Idea")

        // Check failed posts
        #expect(vm.failedPosts.count == 1)
        #expect(vm.failedPosts.first?.body == "Failed Post")

        // Filter by drafts
        vm.currentFilter = .drafts
        #expect(vm.filteredPosts.count == 1)
        #expect(vm.filteredPosts.first?.body == "Draft Idea")

        // Filter all
        vm.currentFilter = .all
        #expect(vm.filteredPosts.count == 2) // Scheduled and Failed
    }
}
