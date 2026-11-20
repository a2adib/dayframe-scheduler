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
    private(set) var errorMessage: String?
    var selectedDate: Date?
    var showsWeek = false
    var selectedPlatform: Platform?

    init(
        postRepository: PostRepository,
        channelRepository: ChannelRepository
    ) {
        self.postRepository = postRepository
        self.channelRepository = channelRepository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            channels = try await channelRepository.loadChannels()
            let queue = try await postRepository.loadQueue()
            let calendar = Calendar.current
            postsByDay = [:]
            for post in queue {
                guard let date = post.scheduledAt else { continue }
                let day = calendar.startOfDay(for: date)
                postsByDay[day, default: []].append(post)
            }
        } catch {
            errorMessage = "Couldn't load calendar posts."
        }
    }

    func posts(on date: Date) -> [Post] {
        let all = postsByDay[Calendar.current.startOfDay(for: date)] ?? []
        guard let platform = selectedPlatform else { return all }
        return all.filter { post in
            let postPlatforms = platforms(for: post)
            return postPlatforms.contains(platform)
        }
    }

    func platforms(for post: Post) -> [Platform] {
        let channelIDs = Set(post.targets.map(\.channelID))
        return channels.filter { channelIDs.contains($0.id) }.map(\.platform)
    }

    func reschedule(post: Post, to newDate: Date) async {
        errorMessage = nil
        do {
            let updated = try await postRepository.reschedule(post, to: newDate)
            let calendar = Calendar.current
            // Remove from old date
            if let oldDate = post.scheduledAt {
                let oldDay = calendar.startOfDay(for: oldDate)
                postsByDay[oldDay]?.removeAll { $0.id == post.id }
            }
            // Add to new date
            let newDay = calendar.startOfDay(for: newDate)
            postsByDay[newDay, default: []].append(updated)
            postsByDay[newDay]?.sort { ($0.scheduledAt ?? .distantPast) < ($1.scheduledAt ?? .distantPast) }
        } catch {
            errorMessage = "Couldn't reschedule post. Please try again."
        }
    }
}
