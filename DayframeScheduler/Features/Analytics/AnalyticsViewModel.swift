import Foundation
import Observation

struct WeekDayStreak: Identifiable {
    let id = UUID()
    let dayLetter: String
    let isCompleted: Bool
}

struct ConsistencyStreakInfo {
    var publishedThisWeek: Int
    var weeklyGoal: Int
    var streakWeeks: Int
    var days: [WeekDayStreak]

    var isGoalAchieved: Bool {
        publishedThisWeek >= weeklyGoal
    }

    var progressFraction: Double {
        min(Double(publishedThisWeek) / Double(max(weeklyGoal, 1)), 1.0)
    }
}

@Observable
@MainActor
final class AnalyticsViewModel {
    private let analyticsRepository: AnalyticsRepository
    private let channelRepository: ChannelRepository
    private let postRepository: PostRepository?

    private(set) var dailyMetrics: [DailyMetrics] = []
    private(set) var topPosts: [TopPost] = []
    private(set) var publishedPerChannel: [ChannelPostCount] = []
    private(set) var channels: [Channel] = []
    private(set) var isLoading = false
    var rangeDays = 7
    var selectedPlatform: Platform?
    var showsProPrompt = false

    // Consistency streaks state (computed from published posts when postRepository is available)
    private(set) var streakInfo = ConsistencyStreakInfo(
        publishedThisWeek: 0,
        weeklyGoal: 5,
        streakWeeks: 0,
        days: [
            WeekDayStreak(dayLetter: "M", isCompleted: false),
            WeekDayStreak(dayLetter: "T", isCompleted: false),
            WeekDayStreak(dayLetter: "W", isCompleted: false),
            WeekDayStreak(dayLetter: "T", isCompleted: false),
            WeekDayStreak(dayLetter: "F", isCompleted: false),
            WeekDayStreak(dayLetter: "S", isCompleted: false),
            WeekDayStreak(dayLetter: "S", isCompleted: false),
        ]
    )

    init(
        analyticsRepository: AnalyticsRepository,
        channelRepository: ChannelRepository,
        postRepository: PostRepository? = nil
    ) {
        self.analyticsRepository = analyticsRepository
        self.channelRepository = channelRepository
        self.postRepository = postRepository
    }

    /// Aggregated reach per day across the selected channels.
    var reachSeries: [(day: Date, reach: Int)] {
        let calendar = Calendar.current
        var buckets: [Date: Int] = [:]
        let selectedIDs = Set(channels.filter { selectedPlatform == nil || $0.platform == selectedPlatform }.map(\.id))
        for metric in dailyMetrics where selectedIDs.contains(metric.channelID) {
            let day = calendar.startOfDay(for: metric.day)
            buckets[day, default: 0] += metric.reach
        }
        return buckets.keys.sorted().map { ($0, buckets[$0]!) }
    }

    var postsPerChannel: [ChannelPostCount] {
        guard let selectedPlatform else { return publishedPerChannel }
        return publishedPerChannel.filter { $0.platform == selectedPlatform }
    }

    /// Percentage change of the second half of the range vs the first half.
    func trend(for selector: (DailyMetrics) -> Int) -> (direction: StatCard.Trend, delta: String) {
        let selectedIDs = Set(channels.filter { selectedPlatform == nil || $0.platform == selectedPlatform }.map(\.id))
        let relevant = dailyMetrics.filter { selectedIDs.contains($0.channelID) }
        let sorted = relevant.sorted { $0.day < $1.day }
        let half = sorted.count / 2
        guard half > 0 else { return (.none, "") }
        let older = sorted[..<half].map(selector).reduce(0, +)
        let newer = sorted[(sorted.count - half)...].map(selector).reduce(0, +)
        guard older > 0 else { return (newer > 0 ? .up : .none, newer > 0 ? "New" : "") }
        let change = Int((Double(newer - older) / Double(older) * 100).rounded())
        if change == 0 { return (.none, "0%") }
        return (change > 0 ? .up : .down, "\(change > 0 ? "+" : "")\(change)%")
    }

    var totals: (reach: Int, engagement: Int, clicks: Int, followers: Int) {
        let selectedIDs = Set(channels.filter { selectedPlatform == nil || $0.platform == selectedPlatform }.map(\.id))
        let relevant = dailyMetrics.filter { selectedIDs.contains($0.channelID) }
        return (
            relevant.map(\.reach).reduce(0, +),
            relevant.map(\.engagement).reduce(0, +),
            relevant.map(\.clicks).reduce(0, +),
            relevant.map(\.followers).reduce(0, +) / max(relevant.count, 1)
        )
    }

    var engagementRateText: String {
        let reach = totals.reach
        guard reach > 0 else { return "0.0%" }
        let rate = (Double(totals.engagement) / Double(reach)) * 100.0
        return String(format: "%.1f%%", rate)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        channels = (try? await channelRepository.loadChannels()) ?? []
        dailyMetrics = (try? await analyticsRepository.loadDailyMetrics(days: rangeDays)) ?? []
        topPosts = (try? await analyticsRepository.loadTopPosts(days: rangeDays, limit: 4)) ?? []
        publishedPerChannel = (try? await analyticsRepository.loadPublishedPerChannel(days: rangeDays)) ?? []
        await refreshStreak()
    }

    private func refreshStreak() async {
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        guard let postRepository,
              let posts = try? await postRepository.loadQueue() else { return }

        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday
        let now = Date.now
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return }

        let publishedDates = posts
            .filter { $0.status == .published }
            .compactMap { $0.publishedAt ?? $0.scheduledAt }

        let thisWeekDates = publishedDates.filter { weekInterval.contains($0) }
        var completedWeekdays: Set<Int> = []
        for date in thisWeekDates {
            // Convert Calendar weekday (Sun=1..Sat=7) to Mon=0..Sun=6
            let wd = (calendar.component(.weekday, from: date) + 5) % 7
            completedWeekdays.insert(wd)
        }

        let dayItems = (0..<7).map { idx in
            WeekDayStreak(dayLetter: letters[idx], isCompleted: completedWeekdays.contains(idx))
        }

        var streakWeeks = thisWeekDates.isEmpty ? 0 : 1
        var checkStart = weekInterval.start
        while let prevStart = calendar.date(byAdding: .weekOfYear, value: -1, to: checkStart) {
            let prevInterval = DateInterval(start: prevStart, end: checkStart)
            if publishedDates.contains(where: { prevInterval.contains($0) }) {
                streakWeeks += 1
                checkStart = prevStart
            } else {
                break
            }
        }

        streakInfo = ConsistencyStreakInfo(
            publishedThisWeek: thisWeekDates.count,
            weeklyGoal: 5,
            streakWeeks: streakWeeks,
            days: dayItems
        )
    }

    /// Converts a TopPost back into a Post object to be pre-populated in the Composer for 1-Click Re-Queue.
    func makeRepurposePost(from topPost: TopPost) -> Post {
        let matchedChannel = channels.first { $0.platform == topPost.platform }
        let target = matchedChannel.map { ch in
            PostTarget(
                id: UUID(),
                channelID: ch.id,
                bodyOverride: nil,
                firstComment: nil,
                status: .draft,
                scheduledAt: nil,
                publishedAt: nil,
                attempts: 0,
                errorMessage: nil
            )
        }

        return Post(
            id: UUID(),
            body: topPost.body,
            status: .draft,
            scheduleMode: .queue,
            scheduledAt: nil,
            publishedAt: nil,
            targets: target.map { [$0] } ?? [],
            media: [],
            firstComment: nil
        )
    }
}
