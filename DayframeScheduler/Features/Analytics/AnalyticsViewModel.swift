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

    private(set) var dailyMetrics: [DailyMetrics] = []
    private(set) var topPosts: [TopPost] = []
    private(set) var publishedPerChannel: [ChannelPostCount] = []
    private(set) var channels: [Channel] = []
    private(set) var isLoading = false
    var rangeDays = 7
    var selectedPlatform: Platform?
    var showsProPrompt = false

    // Consistency streaks state
    private(set) var streakInfo = ConsistencyStreakInfo(
        publishedThisWeek: 4,
        weeklyGoal: 5,
        streakWeeks: 5,
        days: [
            WeekDayStreak(dayLetter: "M", isCompleted: true),
            WeekDayStreak(dayLetter: "T", isCompleted: true),
            WeekDayStreak(dayLetter: "W", isCompleted: true),
            WeekDayStreak(dayLetter: "T", isCompleted: true),
            WeekDayStreak(dayLetter: "F", isCompleted: false),
            WeekDayStreak(dayLetter: "S", isCompleted: false),
            WeekDayStreak(dayLetter: "S", isCompleted: false),
        ]
    )

    init(analyticsRepository: AnalyticsRepository, channelRepository: ChannelRepository) {
        self.analyticsRepository = analyticsRepository
        self.channelRepository = channelRepository
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
        publishedPerChannel
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
