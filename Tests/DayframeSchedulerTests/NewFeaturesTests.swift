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

    @Test
    func channelPauseQueueAndHealth() async throws {
        let channelRepo = MockChannelRepository()
        let channels = try await channelRepo.loadChannels()
        let firstChannel = try #require(channels.first)
        #expect(firstChannel.isPaused == false)
        #expect(firstChannel.connectionHealth == ConnectionHealth.connected)

        // Toggle pause queue on
        try await channelRepo.togglePauseQueue(channelID: firstChannel.id, isPaused: true)
        let updatedChannels = try await channelRepo.loadChannels()
        let pausedChannel = try #require(updatedChannels.first(where: { $0.id == firstChannel.id }))
        #expect(pausedChannel.isPaused == true)
        #expect(pausedChannel.connectionHealth == ConnectionHealth.paused)

        // Toggle pause queue off
        try await channelRepo.togglePauseQueue(channelID: firstChannel.id, isPaused: false)
        let unpausedChannels = try await channelRepo.loadChannels()
        let restoredChannel = try #require(unpausedChannels.first(where: { $0.id == firstChannel.id }))
        #expect(restoredChannel.isPaused == false)
        #expect(restoredChannel.connectionHealth == ConnectionHealth.connected)
    }

    @Test
    func composerPublishingActions() async throws {
        let channelRepo = MockChannelRepository()
        let postRepo = MockPostRepository()
        let scheduleRepo = MockScheduleRepository()

        // 1. Add to Queue
        let vmQueue = ComposerViewModel(channelRepository: channelRepo, postRepository: postRepo, scheduleRepository: scheduleRepo)
        await vmQueue.load()
        vmQueue.bodyText = "Post destined for next available slot"
        vmQueue.publishingAction = .addToQueue
        let queueSuccess = await vmQueue.submit()
        #expect(queueSuccess)
        let queuePosts = try await postRepo.loadQueue()
        #expect(queuePosts.contains(where: { $0.body == "Post destined for next available slot" && $0.status == .scheduled }))

        // 2. Custom Schedule
        let vmSchedule = ComposerViewModel(channelRepository: channelRepo, postRepository: postRepo, scheduleRepository: scheduleRepo)
        await vmSchedule.load()
        vmSchedule.bodyText = "Post destined for custom time"
        vmSchedule.publishingAction = .schedule
        vmSchedule.customDate = Calendar.current.date(byAdding: .day, value: 3, to: .now)!
        let scheduleSuccess = await vmSchedule.submit()
        #expect(scheduleSuccess)
        let scheduledPosts = try await postRepo.loadQueue()
        #expect(scheduledPosts.contains(where: { $0.body == "Post destined for custom time" && $0.scheduleMode == .custom }))

        // 3. Save as Draft
        let vmDraft = ComposerViewModel(channelRepository: channelRepo, postRepository: postRepo, scheduleRepository: scheduleRepo)
        await vmDraft.load()
        vmDraft.bodyText = "Rough draft to refine later"
        vmDraft.publishingAction = .draft
        let draftSuccess = await vmDraft.submit()
        #expect(draftSuccess)
        let drafts = try await postRepo.loadDrafts()
        #expect(drafts.contains(where: { $0.body == "Rough draft to refine later" && $0.status == .draft }))

        // 4. Publish Now
        let vmNow = ComposerViewModel(channelRepository: channelRepo, postRepository: postRepo, scheduleRepository: scheduleRepo)
        await vmNow.load()
        vmNow.bodyText = "Breaking announcement right now"
        vmNow.publishingAction = .publishNow
        let nowSuccess = await vmNow.submit()
        #expect(nowSuccess)
    }

    @Test
    func composerFirstCommentAndOverrides() async throws {
        let channelRepo = MockChannelRepository()
        let postRepo = MockPostRepository()
        let scheduleRepo = MockScheduleRepository()

        let vm = ComposerViewModel(channelRepository: channelRepo, postRepository: postRepo, scheduleRepository: scheduleRepo)
        await vm.load()

        vm.bodyText = "Main post caption"
        vm.firstComment = "Link in bio for full episode! 👇"

        // Default: platform uses master first comment
        #expect(vm.firstCommentFor(platform: .instagram) == "Link in bio for full episode! 👇")
        #expect(!vm.hasFirstCommentOverride(for: .instagram))

        // Set custom override for LinkedIn
        vm.setFirstCommentOverride("Here is the cited whitepaper: https://dayframe.app/research", for: .linkedin)
        #expect(vm.hasFirstCommentOverride(for: .linkedin))
        #expect(vm.firstCommentFor(platform: .linkedin) == "Here is the cited whitepaper: https://dayframe.app/research")
        #expect(vm.firstCommentFor(platform: .instagram) == "Link in bio for full episode! 👇")

        // Clear override
        vm.clearFirstCommentOverride(for: .linkedin)
        #expect(!vm.hasFirstCommentOverride(for: .linkedin))
        #expect(vm.firstCommentFor(platform: .linkedin) == "Link in bio for full episode! 👇")
    }

    @Test
    func queueReorderingAndShuffling() async throws {
        let p1 = Post(id: UUID(), body: "Post 1", status: .scheduled, scheduleMode: .queue, scheduledAt: .now.addingTimeInterval(1000), publishedAt: nil, targets: [], media: [])
        let p2 = Post(id: UUID(), body: "Post 2", status: .scheduled, scheduleMode: .queue, scheduledAt: .now.addingTimeInterval(2000), publishedAt: nil, targets: [], media: [])
        let p3 = Post(id: UUID(), body: "Post 3", status: .scheduled, scheduleMode: .queue, scheduledAt: .now.addingTimeInterval(3000), publishedAt: nil, targets: [], media: [])

        let channelRepo = MockChannelRepository()
        let postRepo = MockPostRepository(posts: [p1, p2, p3])
        let vm = QueueViewModel(channelRepository: channelRepo, postRepository: postRepo)
        await vm.load()

        #expect(vm.posts.count == 3)
        #expect(vm.posts[0].body == "Post 1")
        #expect(vm.posts[1].body == "Post 2")

        // Move Post 1 down
        await vm.movePost(p1, direction: .down)
        #expect(vm.posts[0].body == "Post 2")
        #expect(vm.posts[1].body == "Post 1")

        // Shuffle queue
        await vm.shuffleQueue()
        #expect(vm.posts.count == 3)
    }

    @Test
    func ideasBoardKanbanPipeline() async throws {
        let ideaRepo = MockIdeaRepository()
        let vm = IdeasBoardViewModel(ideaRepository: ideaRepo)
        await vm.load()

        let initialRawCount = vm.count(for: .raw)

        // Add new idea
        await vm.addIdea(
            title: "5 Lessons from Scaling to 10k Users",
            notes: "Focus on onboarding, retention loops, and user interviews",
            stage: .raw,
            tags: ["growth", "saas"],
            link: "https://example.com/notes"
        )

        #expect(vm.count(for: .raw) == initialRawCount + 1)
        let added = try #require(vm.ideas.first(where: { $0.title == "5 Lessons from Scaling to 10k Users" }))
        #expect(added.stage == .raw)
        #expect(added.tags.contains("growth"))

        // Advance to Drafting
        await vm.advanceStage(for: added)
        #expect(vm.ideas.filter { $0.stage == .drafting }.contains(where: { $0.id == added.id }))

        // Advance to Ready
        let draftingIdea = try #require(vm.ideas.first(where: { $0.id == added.id }))
        await vm.advanceStage(for: draftingIdea)
        #expect(vm.ideas.filter { $0.stage == .ready }.contains(where: { $0.id == added.id }))

        // Prefill Composer with this idea
        let composer = ComposerViewModel(
            channelRepository: MockChannelRepository(),
            postRepository: MockPostRepository(),
            scheduleRepository: MockScheduleRepository()
        )
        await composer.load()
        composer.prefill(with: draftingIdea)
        #expect(composer.bodyText.contains("5 Lessons from Scaling to 10k Users"))
        #expect(composer.bodyText.contains("Focus on onboarding"))
        #expect(composer.bodyText.contains("#growth"))
    }

    @Test
    func communityEngagementInbox() async throws {
        let engagementRepo = MockEngagementRepository()
        let channelRepo = MockChannelRepository()
        let vm = EngagementInboxViewModel(engagementRepository: engagementRepo, channelRepository: channelRepo)
        await vm.load()

        #expect(!vm.items.isEmpty)
        let unrepliedCount = vm.unrepliedCount
        #expect(unrepliedCount > 0)

        // Select first unreplied item
        let firstItem = try #require(vm.filteredItems.first)
        #expect(firstItem.isReplied == false)

        // Send inline reply
        await vm.sendReply(to: firstItem, text: "Thanks for checking out Dayframe! Let us know how it goes! 🚀")

        let repliedItem = try #require(vm.items.first(where: { $0.id == firstItem.id }))
        #expect(repliedItem.isReplied == true)
        #expect(repliedItem.replyText == "Thanks for checking out Dayframe! Let us know how it goes! 🚀")
        #expect(repliedItem.repliedAt != nil)

        // Toggle Star
        let starState = repliedItem.isStarred
        await vm.toggleStar(for: repliedItem)
        let toggledStarItem = try #require(vm.items.first(where: { $0.id == firstItem.id }))
        #expect(toggledStarItem.isStarred == !starState)

        // AI Suggested replies
        let suggestions = vm.suggestedReplies(for: firstItem)
        #expect(!suggestions.isEmpty)
    }

    @Test
    func analyticsRepurposeAndStreak() async throws {
        let analyticsRepo = MockAnalyticsRepository()
        let channelRepo = MockChannelRepository()
        let vm = AnalyticsViewModel(analyticsRepository: analyticsRepo, channelRepository: channelRepo)
        await vm.load()

        // Consistency streak widget
        let streak = vm.streakInfo
        #expect(streak.publishedThisWeek >= 0)
        #expect(streak.weeklyGoal == 5)
        #expect(streak.streakWeeks >= 1)

        // Repurpose top post
        let topPosts = vm.topPosts
        if let topPost = topPosts.first {
            let repurposed = vm.makeRepurposePost(from: topPost)
            #expect(repurposed.status == .draft)
            #expect(repurposed.body.contains(topPost.body))
        }
    }
}
