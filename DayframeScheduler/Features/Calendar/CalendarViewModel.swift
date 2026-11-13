import Foundation
import Observation

@Observable
@MainActor
final class CalendarViewModel {
    private let postRepository: PostRepository

    private(set) var postsByDay: [Date: [Post]] = [:]
    private(set) var isLoading = false
    var selectedDate: Date?
    var showsWeek = false

    init(postRepository: PostRepository) {
        self.postRepository = postRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
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
}
