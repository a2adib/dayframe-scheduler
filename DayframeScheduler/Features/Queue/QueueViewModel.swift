import Foundation
import Observation

enum QueueFilter: Hashable, Equatable {
    case all
    case drafts
    case channel(Platform)
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

    func platform(for target: PostTarget) -> Platform? {
        channels.first { $0.id == target.channelID }?.platform
    }
}
