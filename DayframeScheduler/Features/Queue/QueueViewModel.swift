import Foundation
import Observation

enum QueueFilter: Hashable, Equatable {
    case all
    case drafts
    case channel(Platform)
}

enum MoveDirection {
    case up
    case down
}

@Observable
@MainActor
final class QueueViewModel {
    private let channelRepository: ChannelRepository
    private let postRepository: PostRepository

    private(set) var channels: [Channel] = []
    private(set) var posts: [Post] = []
    private(set) var drafts: [Post] = []
    private(set) var isLoading = false
    private(set) var loadError: String?
    var currentFilter: QueueFilter = .all

    init(
        channelRepository: ChannelRepository,
        postRepository: PostRepository
    ) {
        self.channelRepository = channelRepository
        self.postRepository = postRepository
    }

    var failedPosts: [Post] {
        posts.filter { $0.status == .failed }
    }

    var filteredPosts: [Post] {
        switch currentFilter {
        case .all:
            return posts
        case .drafts:
            return drafts
        case .channel(let platform):
            return posts.filter { post in
                post.targets.contains { target in
                    channels.first { $0.id == target.channelID }?.platform == platform
                }
            }
        }
    }

    /// Posts grouped by calendar day, preserving sort order.
    var daySections: [(title: String, posts: [Post])] {
        if case .drafts = currentFilter {
            return drafts.isEmpty ? [] : [("Drafts", drafts)]
        }

        let calendar = Calendar.current
        var buckets: [(title: String, posts: [Post])] = []
        for post in filteredPosts {
            guard let date = post.scheduledAt else {
                if var section = buckets.last, section.title == "Unscheduled" {
                    section.posts.append(post)
                    buckets[buckets.count - 1] = section
                } else {
                    buckets.append(("Unscheduled", [post]))
                }
                continue
            }
            let title: String
            if calendar.isDateInToday(date) {
                title = "Today"
            } else if calendar.isDateInTomorrow(date) {
                title = "Tomorrow"
            } else {
                title = date.formatted(.dateTime.month(.wide).day().weekday(.wide))
            }
            if var section = buckets.last, section.title == title {
                section.posts.append(post)
                buckets[buckets.count - 1] = section
            } else {
                buckets.append((title, [post]))
            }
        }
        return buckets
    }

    func load() async {
        isLoading = true
        loadError = nil
        do {
            channels = try await channelRepository.loadChannels()
            posts = try await postRepository.loadQueue()
            drafts = (try? await postRepository.loadDrafts()) ?? []
        } catch {
            loadError = "Couldn't load your queue. Check your connection and retry."
        }
        isLoading = false
    }

    func delete(_ post: Post) async {
        try? await postRepository.delete(post)
        posts.removeAll { $0.id == post.id }
        drafts.removeAll { $0.id == post.id }
    }

    func duplicate(_ post: Post) async {
        if let copy = try? await postRepository.duplicate(post) {
            posts.append(copy)
        }
    }

    // MARK: - Queue Reordering & Shuffle

    /// Only future, still-scheduled posts visible under the current filter can
    /// be reordered. Published/failed history must never receive a new time,
    /// and a scheduled post must never be handed a past time (it would publish
    /// immediately).
    private func reorderablePosts() -> [Post] {
        let visible = Set(filteredPosts.map(\.id))
        let now = Date.now
        return posts
            .filter { post in
                guard post.status == .scheduled, visible.contains(post.id),
                      let scheduledAt = post.scheduledAt else { return false }
                return scheduledAt > now
            }
            .sorted { ($0.scheduledAt ?? .distantPast) < ($1.scheduledAt ?? .distantPast) }
    }

    private func setTime(_ date: Date, on post: Post) -> Post {
        var updated = post
        updated.scheduledAt = date
        updated.targets = post.targets.map { var t = $0; t.scheduledAt = date; return t }
        return updated
    }

    private func apply(_ changed: [Post]) async {
        let byID = Dictionary(uniqueKeysWithValues: changed.map { ($0.id, $0) })
        let previous = posts
        posts = posts
            .map { byID[$0.id] ?? $0 }
            .sorted { ($0.scheduledAt ?? .distantPast) < ($1.scheduledAt ?? .distantPast) }
        do {
            try await postRepository.reorderQueue(posts: changed)
        } catch {
            posts = previous
            loadError = "Couldn't reorder the queue. Please try again."
        }
    }

    func movePost(_ post: Post, direction: MoveDirection) async {
        let reorderable = reorderablePosts()
        guard let currentIndex = reorderable.firstIndex(where: { $0.id == post.id }) else { return }
        let targetIndex = direction == .up ? currentIndex - 1 : currentIndex + 1
        guard reorderable.indices.contains(targetIndex),
              let currentTime = reorderable[currentIndex].scheduledAt,
              let targetTime = reorderable[targetIndex].scheduledAt else { return }

        // Swap timestamps so the timeline slots stay put while posts move.
        await apply([
            setTime(targetTime, on: reorderable[currentIndex]),
            setTime(currentTime, on: reorderable[targetIndex]),
        ])
    }

    func shuffleQueue() async {
        let reorderable = reorderablePosts()
        guard reorderable.count > 1 else { return }
        // Keep the slot times fixed and shuffle which post lands in each.
        let timestamps = reorderable.compactMap(\.scheduledAt)
        let shuffled = reorderable.shuffled()
        await apply(zip(shuffled, timestamps).map { setTime($1, on: $0) })
    }

    func platform(for target: PostTarget) -> Platform? {
        channels.first { $0.id == target.channelID }?.platform
    }
}
