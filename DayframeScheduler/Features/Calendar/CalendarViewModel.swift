import Foundation
import Observation

@Observable
@MainActor
final class CalendarViewModel {
    private let postRepository: PostRepository
    private let channelRepository: ChannelRepository

    private(set) var channels: [Channel] = []
    private(set) var postsByDay: [Date: [Post]] = [:]
    private(set) var isLoading = false
    var selectedDate: Date?
    var showsWeek = false

    init(
        postRepository: PostRepository,
        channelRepository: ChannelRepository
    ) {
        self.postRepository = postRepository
        self.channelRepository = channelRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        channels = (try? await channelRepository.loadChannels()) ?? []
        let queue = (try? await postRepository.loadQueue()) ?? []
        let calendar = Calendar.current
        postsByDay = [:]
        for post in queue {
            guard let date = post.scheduledAt else { continue }
            let day = calendar.startOfDay(for: date)
            postsByDay[day, default: []].append(post)
        }
    }

    func posts(on date: Date) -> [Post] {
        postsByDay[Calendar.current.startOfDay(for: date)] ?? []
    }

    func platforms(for post: Post) -> [Platform] {
        let channelIDs = Set(post.targets.map(\.channelID))
        let matched = channels.filter { channelIDs.contains($0.id) }.map(\.platform)
        return matched.isEmpty ? [.instagram] : matched
    }
}
